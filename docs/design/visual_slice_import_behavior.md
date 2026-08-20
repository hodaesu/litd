# Comportement d'import progressif

L'absence de GLB est un état normal avant la session PC. La scène finale doit rester lançable : le loader conserve alors les proxies. Une fois un GLB présent, il ne remplace son proxy que si le contrat runtime est satisfait.
