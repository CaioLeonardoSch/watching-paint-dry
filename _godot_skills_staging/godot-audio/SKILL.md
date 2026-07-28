---
name: godot-audio
description: Áudio em Godot 4 — AudioStreamPlayer vs AudioStreamPlayer2D vs AudioStreamPlayer3D, audio buses, atenuação e reverb para ambientes pequenos/internos, música ambiente vs efeitos pontuais. Use quando a dúvida envolver som, música, efeitos sonoros, ou mixagem de áudio. O projeto ainda não tem áudio implementado — esta skill é referência para quando isso for adicionado.
---

# Áudio em Godot 4

## Estado atual deste projeto

Nenhum áudio implementado ainda. Esta skill é referência prospectiva — quando o projeto ganhar
som (ambiente, música, efeito de tinta secando, etc.), comece por aqui.

## Escolher o tipo de player

- **`AudioStreamPlayer`** — sem posição no espaço, volume constante independente da câmera. Certo
  para música de fundo/ambiente geral do quarto (ex: trilha contemplativa, chuva ambiente que deve
  soar igual em qualquer canto do cômodo).
- **`AudioStreamPlayer3D`** — som posicional, atenua com distância e é afetado por
  `AudioListener3D`/posição da câmera. Certo para som pontual com fonte física (o próprio processo
  de secagem da tinta, um relógio na parede, passos). Como o quarto é pequeno (7×6m), a atenuação
  de um `AudioStreamPlayer3D` precisa de `unit_size` baixo — o padrão (1.0) assume escala de
  ambiente aberto e pode deixar o som quase inaudível num cômodo desse tamanho.
- **`AudioStreamPlayer2D`** — não se aplica aqui (projeto é 3D).

## Audio buses

Buses (Project Settings → Audio, ou `AudioServer` via código) permitem agrupar e mixar por
categoria sem tocar em cada player individualmente:

```
Master
 ├─ Ambiente   (som de fundo do quarto, chuva, etc.)
 ├─ Efeitos    (sons pontuais/reativos)
 └─ Musica     (trilha, se houver)
```

Cada `AudioStreamPlayer*` tem uma propriedade `bus` (string com o nome do bus). Volume geral,
mute e efeitos (reverb, EQ) devem ir no bus, não em cada player — isso permite, por exemplo, um
slider único de "volume ambiente" nas configurações do jogo sem enumerar todos os players.

## Reverb para ambiente interno pequeno

Um quarto fechado de ~7×6×3m tem reflexão sonora bem diferente de ambiente aberto. Godot 4 tem
`AudioEffectReverb`, adicionado a um bus (não a um player individual):

- `room_size` baixo (~0.1–0.3) para um cômodo pequeno — valores altos (perto de 1.0) soam como
  catedral/hangar.
- `wet` moderado (~0.2–0.4) — reverb sutil, não deve dominar o som direto num quarto realista.
- Aplicar no bus `Ambiente`/`Efeitos`, não no `Master`, para não afetar música que já vem
  mixada/masterizada.

## Erros comuns

- Usar `AudioStreamPlayer3D` para música de fundo — ela vai variar de volume conforme a câmera se
  move/olha, o que é errado para algo que deveria soar uniforme.
- Não setar `bus` explicitamente — todo player nasce no bus `Master` por padrão, o que impede
  mixagem por categoria depois.
- Esquecer `autoplay` vs iniciar por código — para som ambiente contínuo (chuva, ruído de fundo),
  `autoplay = true` no player evita ter que lembrar de chamar `.play()` no `_ready()` de outro
  script.
- Volume em `AudioStreamPlayer` é em **decibéis** (`volume_db`), não fração linear (0–1). `-80` é
  praticamente silêncio, `0` é volume original do stream, positivo amplifica (risco de clipping).
