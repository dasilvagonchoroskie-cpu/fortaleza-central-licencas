package br.com.fortalezadigitalsecurity.licencas

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * Aviso de pedido de liberacao novo, mesmo com a Central fechada.
 *
 * Usa o agendador do proprio Android (JobScheduler): de 15 em 15 minutos,
 * com internet, pergunta ao servidor quantos pedidos estao esperando e
 * mostra uma notificacao quando chega um novo. Nao usa biblioteca externa
 * (a versao 3.0.0 usava o WorkManager, que fechava o app ao abrir).
 */
class AvisosJob : JobService() {

    companion object {
        const val PREFS = "central_avisos"
        const val SERVIDOR = "servidor"
        const val SENHA = "senha"
        const val LIGADO = "ligado"
        const val ULTIMO_AVISADO = "ultimo_avisado"
        private const val ID_TAREFA = 4711
        private const val CANAL = "pedidos"

        /** Liga ou desliga a conferencia de 15 em 15 minutos. Nunca derruba o app. */
        fun configurar(contexto: Context, servidor: String, senha: String, ligado: Boolean) {
            try {
                contexto.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                    .putString(SERVIDOR, servidor)
                    .putString(SENHA, senha)
                    .putBoolean(LIGADO, ligado)
                    .apply()
                val agenda = contexto.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
                if (ligado && servidor.isNotEmpty() && senha.isNotEmpty()) {
                    val tarefa = JobInfo.Builder(ID_TAREFA, ComponentName(contexto, AvisosJob::class.java))
                        .setPeriodic(15 * 60 * 1000L)
                        .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
                        .setPersisted(true)
                        .build()
                    agenda.schedule(tarefa)
                } else {
                    agenda.cancel(ID_TAREFA)
                }
            } catch (erro: Exception) {
                // Sem agendador neste celular: a Central segue funcionando sem aviso.
            }
        }

        /** Pergunta ao servidor e avisa se chegou pedido novo. */
        fun conferir(contexto: Context) {
            val prefs = contexto.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            if (!prefs.getBoolean(LIGADO, false)) return
            val servidor = (prefs.getString(SERVIDOR, "") ?: "").trimEnd('/')
            val senha = prefs.getString(SENHA, "") ?: ""
            if (servidor.isEmpty() || senha.isEmpty()) return
            val conexao = URL("$servidor/admin/resumo").openConnection() as HttpURLConnection
            try {
                conexao.connectTimeout = 15000
                conexao.readTimeout = 20000
                conexao.setRequestProperty("Authorization", "Bearer $senha")
                if (conexao.responseCode != 200) return
                val texto = conexao.inputStream.bufferedReader().use { it.readText() }
                val resumo = JSONObject(texto)
                val pendentes = resumo.optInt("pedidos_pendentes", 0)
                val ultimo = if (resumo.isNull("ultimo_pedido_em")) "" else resumo.optString("ultimo_pedido_em", "")
                val avisado = prefs.getString(ULTIMO_AVISADO, "") ?: ""
                if (pendentes > 0 && ultimo.isNotEmpty() && ultimo > avisado) {
                    val primeiro = resumo.optJSONArray("pedidos_recentes")?.optJSONObject(0)
                    val titulo = if (pendentes == 1) "Pedido de liberação" else "$pendentes pedidos de liberação"
                    val corpo = if (primeiro != null) {
                        "${primeiro.optString("nome")} — ${primeiro.optString("app_nome")} (código ${primeiro.optString("codigo")})"
                    } else {
                        "Abra a Central para liberar."
                    }
                    notificar(contexto, titulo, corpo)
                    prefs.edit().putString(ULTIMO_AVISADO, ultimo).apply()
                }
            } finally {
                conexao.disconnect()
            }
        }

        private fun notificar(contexto: Context, titulo: String, corpo: String) {
            if (Build.VERSION.SDK_INT >= 33 &&
                contexto.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
            ) return
            val gerente = contexto.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val abrir = contexto.packageManager.getLaunchIntentForPackage(contexto.packageName) ?: return
            val toque = PendingIntent.getActivity(
                contexto, 0, abrir, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            val construtor = if (Build.VERSION.SDK_INT >= 26) {
                gerente.createNotificationChannel(
                    NotificationChannel(CANAL, "Pedidos de liberação", NotificationManager.IMPORTANCE_HIGH)
                )
                Notification.Builder(contexto, CANAL)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(contexto)
            }
            val aviso = construtor
                .setSmallIcon(R.drawable.ic_aviso)
                .setContentTitle(titulo)
                .setContentText(corpo)
                .setStyle(Notification.BigTextStyle().bigText(corpo))
                .setAutoCancel(true)
                .setContentIntent(toque)
                .build()
            gerente.notify(1, aviso)
        }
    }

    override fun onStartJob(params: JobParameters): Boolean {
        Thread {
            try {
                conferir(applicationContext)
            } catch (erro: Exception) {
                // Sem internet ou servidor fora: tenta de novo na proxima rodada.
            }
            jobFinished(params, false)
        }.start()
        return true
    }

    override fun onStopJob(params: JobParameters): Boolean = true
}
