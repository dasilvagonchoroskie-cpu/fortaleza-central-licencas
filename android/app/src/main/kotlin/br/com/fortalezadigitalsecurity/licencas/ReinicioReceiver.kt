package br.com.fortalezadigitalsecurity.licencas

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Depois de reiniciar o celular, liga o monitor de novo (se estava ligado),
 * para o aviso de pedido voltar sozinho sem precisar abrir a Central.
 */
class ReinicioReceiver : BroadcastReceiver() {
    override fun onReceive(contexto: Context, intent: Intent?) {
        val prefs = contexto.getSharedPreferences(AvisosJob.PREFS, Context.MODE_PRIVATE)
        val ligado = prefs.getBoolean(AvisosJob.LIGADO, false)
        val temSenha = (prefs.getString(AvisosJob.SENHA, "") ?: "").isNotEmpty()
        if (ligado && temSenha) {
            MonitorService.ligar(contexto)
        }
    }
}
