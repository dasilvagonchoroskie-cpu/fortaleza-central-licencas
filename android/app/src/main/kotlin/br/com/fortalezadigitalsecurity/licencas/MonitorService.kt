package br.com.fortalezadigitalsecurity.licencas

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Monitor dos pedidos de liberacao.
 *
 * Fica rodando em PRIMEIRO PLANO (foreground service) e, a cada ~45 segundos,
 * pergunta ao servidor se chegou pedido novo. Quando chega, mostra a
 * notificacao na barra na hora — mesmo com a Central fechada.
 *
 * Por que assim: o agendador comum do Android (JobScheduler) segura os avisos
 * quando o app esta fechado (economia de bateria/Doze), entao o aviso quase
 * nao chegava. Um servico em primeiro plano o Android nao segura — por isso
 * ele carrega uma notificacao fixa discreta ("vigiando pedidos").
 *
 * Nao fecha ao tirar o app dos recentes (stopWithTask=false) e volta sozinho
 * se o sistema o encerrar (START_STICKY).
 */
class MonitorService : Service() {

    @Volatile
    private var rodando = false
    private var linha: Thread? = null

    companion object {
        private const val ID_NOTIF_FIXA = 2
        const val CANAL_MONITOR = "monitor"
        private const val INTERVALO_MS = 45_000L

        /** Liga o monitor (se ainda nao estiver rodando). */
        fun ligar(contexto: Context) {
            try {
                val intent = Intent(contexto, MonitorService::class.java)
                if (Build.VERSION.SDK_INT >= 26) {
                    contexto.startForegroundService(intent)
                } else {
                    contexto.startService(intent)
                }
            } catch (_: Exception) {
                // Em alguns casos o Android nao deixa iniciar em segundo plano;
                // o JobScheduler de reserva cobre ate a proxima abertura.
            }
        }

        fun desligar(contexto: Context) {
            try {
                contexto.stopService(Intent(contexto, MonitorService::class.java))
            } catch (_: Exception) {
            }
        }

        /** Notificacao fixa e discreta que mantem o monitor vivo. */
        fun notificacaoFixa(contexto: Context): Notification {
            val gerente = contexto.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= 26) {
                val canal = NotificationChannel(
                    CANAL_MONITOR, "Vigia de pedidos", NotificationManager.IMPORTANCE_MIN,
                ).apply { setShowBadge(false) }
                gerente.createNotificationChannel(canal)
            }
            val abrir = contexto.packageManager.getLaunchIntentForPackage(contexto.packageName)
            val toque = if (abrir != null) {
                PendingIntent.getActivity(contexto, 0, abrir, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            } else {
                null
            }
            val construtor = if (Build.VERSION.SDK_INT >= 26) {
                Notification.Builder(contexto, CANAL_MONITOR)
            } else {
                @Suppress("DEPRECATION") Notification.Builder(contexto)
            }
            return construtor
                .setSmallIcon(R.drawable.ic_aviso)
                .setContentTitle("Central de Licenças")
                .setContentText("Vigiando pedidos de liberação")
                .setOngoing(true)
                .apply {
                    if (Build.VERSION.SDK_INT >= 24) setPriority(Notification.PRIORITY_MIN)
                    if (toque != null) setContentIntent(toque)
                }
                .build()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        entrarEmPrimeiroPlano()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        entrarEmPrimeiroPlano()
        // Se o monitor foi desligado nas configuracoes, nao insiste.
        val ligado = getSharedPreferences(AvisosJob.PREFS, Context.MODE_PRIVATE).getBoolean(AvisosJob.LIGADO, false)
        if (!ligado) {
            pararTudo()
            return START_NOT_STICKY
        }
        iniciarLinha()
        return START_STICKY
    }

    private fun entrarEmPrimeiroPlano() {
        try {
            val notif = notificacaoFixa(this)
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(ID_NOTIF_FIXA, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else {
                startForeground(ID_NOTIF_FIXA, notif)
            }
        } catch (_: Exception) {
        }
    }

    private fun iniciarLinha() {
        if (rodando) return
        rodando = true
        linha = Thread {
            while (rodando) {
                try {
                    AvisosJob.conferir(applicationContext)
                } catch (_: Exception) {
                }
                var dormiu = 0L
                while (rodando && dormiu < INTERVALO_MS) {
                    try {
                        Thread.sleep(1000)
                    } catch (_: InterruptedException) {
                        break
                    }
                    dormiu += 1000
                }
            }
        }.apply { isDaemon = true; start() }
    }

    private fun pararTudo() {
        rodando = false
        linha?.interrupt()
        linha = null
        try {
            if (Build.VERSION.SDK_INT >= 24) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
        } catch (_: Exception) {
        }
        stopSelf()
    }

    override fun onDestroy() {
        rodando = false
        linha?.interrupt()
        linha = null
        super.onDestroy()
    }
}
