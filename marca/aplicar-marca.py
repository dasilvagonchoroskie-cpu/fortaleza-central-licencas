# Aplica o icone e a tela de abertura da Central no projeto Android gerado
# pelo Capacitor (roda na esteira, depois do "cap sync" e antes de compilar).
import glob, os, shutil
from PIL import Image

RES = 'android/app/src/main/res'
AQUI = os.path.dirname(os.path.abspath(__file__))
FUNDO = (11, 29, 20, 255)

for raiz, _, arquivos in os.walk(os.path.join(AQUI, 'res')):
    for nome in arquivos:
        origem = os.path.join(raiz, nome)
        destino = os.path.join(RES, os.path.relpath(origem, os.path.join(AQUI, 'res')))
        os.makedirs(os.path.dirname(destino), exist_ok=True)
        shutil.copyfile(origem, destino)
        print('icone:', destino)

logo = Image.open(os.path.join(AQUI, 'logo-abertura.png')).convert('RGBA')
telas = glob.glob(os.path.join(RES, 'drawable*', 'splash.png'))
for caminho in telas:
    largura, altura = Image.open(caminho).size
    tela = Image.new('RGBA', (largura, altura), FUNDO)
    lado = int(min(largura, altura) * 0.42)
    tela.alpha_composite(logo.resize((lado, lado), Image.LANCZOS), ((largura - lado) // 2, (altura - lado) // 2))
    tela.convert('RGB').save(caminho)
    print('abertura:', caminho, largura, 'x', altura)
if not telas:
    raise SystemExit('ERRO: nao achei a tela de abertura do Capacitor')
