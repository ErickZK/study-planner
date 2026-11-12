# Design system

`lib/app/theme/app_theme.dart` centraliza cores, tipografia, espaçamentos, raio, divisórias e estados de interação. Material 3, fundo branco, texto carvão, cinzas para borda/hover/foco; erro usa vermelho discreto. Sem gradientes, roxo, fontes remotas ou marcas externas.

Espaçamentos de 8/16/24 pixels, raio de 8, borda de 1. Tipografia de 14/16/20/28 com hierarquia de pesos. Controles Material mantêm foco, teclado e áreas de toque padrão. Nenhum componente compartilhado artificial foi introduzido.

Layout: breakpoint em 840 pixels, sidebar de 250 no desktop; drawer em telas estreitas. Formulários e dashboard usam ListView para acomodar teclado e telas pequenas. SafeArea preserva áreas do sistema. Validação visual em dispositivo, escala de texto elevada e navegação completa por teclado ainda pendentes; testes escritos cobrem 390×844 e 1280×800.
