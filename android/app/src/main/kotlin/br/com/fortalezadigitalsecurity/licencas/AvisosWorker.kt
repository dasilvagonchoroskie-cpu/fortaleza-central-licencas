package br.com.fortalezadigitalsecurity.licencas

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * Confere no servidor de licencas se chegou pedido de liberacao novo e
 * mostra uma notificacao. Roda de 15 em 15 minutos (o minimo do Android),
 * so com internet, mesmo com a Central fechada.
 */
class AvisosWorker(contexto: Context, parametros: WorkerParameters) : Worker(contexto, parametros) {

    companion object {
        const val NOME = "pedidos-de-liberacao"
        const val PREFS = "central_avisos"
        const val SERVIDOR = "servidor"
        const val SENHA = "senha"
        const val LIGADO = "ligado"
        const val ULTIMO_AVISADO = "ultimo_avisado"
        private const val CANAL = "pedidos"
    }

    override fun doWork(): Result {
        val prefs = applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(LIGADO, false)) return Result.success()
        val servidor = (prefs.getString(SERVIDOR, "") ?: "").trimEnd('/')
        val senha = prefs.getString(SENHA, "") ?: ""
        if (servidor.isEmpty() || senha.isEmpty()) return Result.success()
        try {
            val conexao = URL("$servidor/admin/resumo").openConnection() as HttpURLConnection
            conexao.connectTimeout = 15000
            conexao.readTimeout = 20000
            conexao.setRequestProperty("Authorization", "Bearer $senha")
            if (conexao.responseCode != 200) return Result.success()
            val texto = conexao.inputStream.bufferedReader().use { it.readText() }
            conexao.disconnect()
            val resumo = JSONObject(texto)
            val pendentes = resumo.optInt("pedidos_pendentes", 0)
            val ultimo = if (resumo.isNull("ultimo_pedido_em")) "" else resumo.optString("ultimo_pedido_em", "")
            val avisado = prefs.getString(ULTIMO_AVISADO, "") ?: ""
            if (pendentes > 0 && ultimo.isNotEmpty() && ultimo > avisado) {
                val recentes = resumo.optJSONArray("pedidos_recentes")
                val primeiro = recentes?.optJSONObject(0)
                val titulo = if (pendentes == 1) "Pedido de liberação" else "$pendentes pedidos de liberação"
                val corpo = if (primeiro != null) {
                    "${primeiro.optString("nome")} — ${primeiro.optString("app_nome")} (código ${primeiro.optString("codigo")})"
                } else {
                    "Abra a Central para liberar."
                }
                notificar(titulo, corpo)
                prefs.edit().putString(ULTIMO_AVISADO, ultimo).apply()
            }
        } catch (erro: Exception) {
            // Sem internet ou servidor fora: tenta de novo na proxima rodada.
        }
        return Result.success()
    }

    private fun notificar(titulo: String, corpo: String) {
        val contexto = applicationContext
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
