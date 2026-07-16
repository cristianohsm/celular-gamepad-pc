# Política de segurança

Este projeto foi projetado para uma rede local confiável. Não encaminhe a porta TCP 8765 e não exponha o servidor diretamente na internet; o PIN temporário não substitui autenticação apropriada para uso público.

O bridge XInput experimental não abre porta e aceita somente JSON Lines pelo processo pai. A instalação do HIDMaestro altera stores de certificados e Driver Store, exige consentimento/UAC e deve usar exclusivamente o asset fixado em `dependencies.lock.json`. Nunca compartilhe logs que revelem caminhos locais.

Para relatar uma vulnerabilidade, use uma **GitHub Security Advisory privada** deste repositório, se o recurso estiver disponível. Inclua versão, impacto, passos mínimos de reprodução e uma sugestão de correção. Não publique uma exploração completa em issue pública antes que haja uma correção coordenada.
