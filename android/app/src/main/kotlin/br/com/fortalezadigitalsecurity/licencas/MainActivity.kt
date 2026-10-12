package br.com.fortalezadigitalsecurity.licencas

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Aviso de pedido novo: o Flutter liga/desliga e passa endereco e senha;
        // quem confere de 15 em 15 minutos e o AvisosJob.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "central/avisos")
            .setMethodCallHandler { chamada, resultado ->
                when (chamada.method) {
                    "configurar" -> {
                        val servidor = chamada.argument<String>("servidor") ?: ""
                        val senha = chamada.argument<String>("senha") ?: ""
                        val ligado = chamada.argument<Boolean>("ligado") ?: false
                        AvisosJob.configurar(applicationContext, servidor, senha, ligado)
                        resultado.success(null)
                    }
                    "pedirPermissao" -> {
                        if (Build.VERSION.SDK_INT >= 33 &&
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                        ) {
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 7)
                        }
                        resultado.success(null)
                    }
                    "marcarVisto" -> {
                        val ultimo = chamada.argument<String>("ultimo") ?: ""
                        val prefs = applicationContext.getSharedPreferences(AvisosJob.PREFS, Context.MODE_PRIVATE)
                        val atual = prefs.getString(AvisosJob.ULTIMO_AVISADO, "") ?: ""
                        if (ultimo > atual) prefs.edit().putString(AvisosJob.ULTIMO_AVISADO, ultimo).apply()
                        resultado.success(null)
                    }
                    else -> resultado.notImplemented()
                }
            }
    }
}
