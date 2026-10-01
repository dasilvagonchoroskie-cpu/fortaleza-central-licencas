// Teste da tela da Central (sem celular): roda o www/index.html num navegador
// simulado (jsdom), com o servidor e a area de transferencia de mentira.
// A esteira roda isto ANTES de montar o APK: se falhar, o APK nao sai.
// Cobre o defeito de 01/10/2026: duas funcoes "copiarTexto", a tela dizia
// "Nao consegui copiar" sempre; e a chave gerada para o app errado.
import { JSDOM } from 'jsdom';
import fs from 'node:fs';
const html = fs.readFileSync(new URL('../www/index.html', import.meta.url), 'utf8');
const LINK = 'https://github.com/dasilvagonchoroskie-cpu/taximetro/releases/download/apk-mais-recente/taximetro.apk';
let area = '';
let apps = [{ id: 'taximetro', nome: 'Taximetro', link: LINK, chaves: 1 }];
const dom = new JSDOM(html, { runScripts: 'dangerously', url: 'https://localhost/', beforeParse(w) {
  w.localStorage.setItem('admin_senha', 'senha-de-teste-123');
  w.fetch = async (url) => {
    const rota = new URL(url).pathname;
    let corpo = { ok: true };
    if (rota === '/admin/apps') corpo = { ok: true, apps };
    if (rota === '/admin/gerar') corpo = { ok: true, chave: 'YJJ4-3GVY-YMTH-7L6P', validade: '2026-10-31T18:05:29.926Z', app_id: 'taximetro', app_nome: 'Taximetro', link: LINK };
    return { status: 200, json: async () => corpo };
  };
  w.Capacitor = { Plugins: { Clipboard: { write: async ({ string }) => { area = string; } } } };
}});
const w = dom.window; const $ = (id) => w.document.getElementById(id);
const espera = () => new Promise((r) => setTimeout(r, 50));
let falhas = 0;
const conf = (n, ok, x = '') => { console.log((ok ? 'OK    ' : 'FALHA ') + n + (ok ? '' : '  ' + x)); if (!ok) falhas++; };
await espera();

conf('existe uma funcao copiarTexto so', (html.match(/function copiarTexto\(/g) || []).length === 1);
conf('com um app so, ele ja vem escolhido', $('gerar-app').value === 'taximetro', $('gerar-app').innerHTML);
$('gerar-cliente').value = 'Fabiano Silva';
w.gerarChave(); await espera();
conf('caixa mostra para qual app e a chave', $('aviso-app').textContent === 'Chave do aplicativo Taximetro');
w.copiarChaveNova(); await espera();
conf('copiar a chave: copia e diz que copiou', area === 'YJJ4-3GVY-YMTH-7L6P' && $('recado-gerar').textContent === 'Chave copiada.', $('recado-gerar').textContent);
w.copiarRecado(); await espera();
conf('recado leva o link, a chave numa linha sozinha e o prazo', area.includes(LINK) && area.includes('\nYJJ4-3GVY-YMTH-7L6P\n') && area.includes('31/10/2026'), area);
conf('recado cumprimenta pelo primeiro nome', area.startsWith('Olá, Fabiano!'), area.slice(0, 40));
const re = /(?:^|[^A-Za-z0-9_-])([A-HJ-NP-Za-hj-np-z2-9]{4}-[A-HJ-NP-Za-hj-np-z2-9]{4}-[A-HJ-NP-Za-hj-np-z2-9]{4}-[A-HJ-NP-Za-hj-np-z2-9]{4})(?=$|[^A-Za-z0-9_-])/;
conf('o taximetro acha a chave no recado inteiro', (area.match(re) || [])[1] === 'YJJ4-3GVY-YMTH-7L6P');
conf('numero com DDD vira 55+DDD', w.foneParaWhatsApp('64 99999-8888') === '5564999998888');
conf('numero com +55 fica como esta', w.foneParaWhatsApp('+55 (64) 99999-8888') === '5564999998888');
conf('sem numero: abre a lista de contatos', w.foneParaWhatsApp('  ') === '');
conf('numero estranho e recusado', w.foneParaWhatsApp('12345') === null);
console.log('--- recado ---\n' + area + '\n--------------');

// sem plugin e sem navegador: o jeito antigo falha -> tem que dizer que NAO copiou
w.Capacitor.Plugins.Clipboard.write = async () => { throw new Error('x'); };
w.document.execCommand = () => false;
w.copiarChaveNova(); await espera();
conf('quando nao copia, diz a verdade', $('recado-gerar').textContent.startsWith('Não consegui copiar'), $('recado-gerar').textContent);

// varios apps: comeca em "Escolha"
apps = [apps[0], { id: 'meu-frete', nome: 'Meu Frete', link: '', chaves: 0 }];
await w.carregarApps(); await espera();
conf('com dois apps, a lista comeca em "Escolha o aplicativo"', $('gerar-app').value === '', $('gerar-app').value);
w.gerarChave(); await espera();
conf('sem escolher, nao gera', $('recado-gerar').textContent.startsWith('Escolha o aplicativo'), $('recado-gerar').textContent);
conf('app sem chave tem botao Apagar, com chave nao', ($('lista-apps').innerHTML.match(/Apagar/g) || []).length === 1);
console.log(falhas ? falhas + ' FALHA(S)' : 'TUDO CERTO');
process.exit(falhas ? 1 : 0);
