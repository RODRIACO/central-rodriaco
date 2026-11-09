/* Service worker da Central Rodriaço.
   Existe só para o navegador oferecer "Instalar app". NÃO guarda nada em cache:
   toda abertura busca a versão mais nova do site, então ninguém fica preso numa versão velha. */
self.addEventListener('install', function () { self.skipWaiting(); });
self.addEventListener('activate', function (e) { e.waitUntil(self.clients.claim()); });
self.addEventListener('fetch', function () { /* sem cache: o navegador segue pela rede normalmente */ });
