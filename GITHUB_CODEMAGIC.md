# WG Keys SF2 Player 2.1 — GitHub + Codemagic

Este projeto já contém `codemagic.yaml` na raiz para gerar um APK Android na nuvem.

## 1. Criar o repositório no GitHub

Crie um repositório vazio, por exemplo:

`WG-Keys-SF2-Player`

Pode deixá-lo privado.

**Importante:** envie os arquivos do projeto para o repositório; não coloque apenas o ZIP dentro dele.

A raiz deve ficar parecida com:

```text
WG-Keys-SF2-Player/
├── android/
├── lib/
├── pubspec.yaml
├── codemagic.yaml
├── README.md
└── .gitignore
```

## 2. Abrir no Codemagic

Entre no Codemagic e conecte sua conta GitHub.

Adicione o repositório `WG-Keys-SF2-Player`.

Como `codemagic.yaml` já está na raiz, o Codemagic poderá detectar o workflow `wg-keys-android`.

## 3. Iniciar o build

Selecione o workflow:

`WG Keys SF2 Player 2.1 - Android APK`

Inicie o build.

O workflow:

1. configura o caminho do Flutter;
2. executa `flutter pub get`;
3. cria o Gradle wrapper caso ele não esteja no ZIP, preservando os arquivos Android específicos do WG Keys;
4. verifica a integração do FluidSynth;
5. executa `flutter build apk --release`.

## 4. Baixar o APK

Quando o build terminar, abra **Artifacts** e baixe o arquivo `.apk`.

Instale o APK no Redmi 12C.

### Observação sobre assinatura

Este projeto está configurado para facilitar o primeiro build/teste. A publicação na Google Play exige uma chave de assinatura própria e configuração de code signing no Codemagic. Não use uma chave de debug para publicar atualizações na Play Store.
