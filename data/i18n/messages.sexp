;;;; User interface strings per locale. Translations are welcome as pull requests.
;;;; Format: (KEY :en "English" :pt-br "Português"); ~D and ~A are FORMAT directives.
(
 (:site-name :en "CLDocs" :pt-br "CLDocs")
 (:tagline :en "Community reference for Common Lisp." :pt-br "Referência da comunidade para Common Lisp.")
 (:home-lede :en "Every symbol of Common Lisp on its own page: signature, documentation, examples and cross references."
             :pt-br "Cada símbolo do Common Lisp em sua própria página: assinatura, documentação, exemplos e referências cruzadas.")
 (:search-placeholder :en "Search symbols: car, mapcar, *print-base*" :pt-br "Buscar símbolos: car, mapcar, *print-base*")
 (:search-label :en "Search symbols" :pt-br "Buscar símbolos")
 (:logo-aria :en "CLDocs home" :pt-br "Início do CLDocs")
 (:nav-packages :en "Packages" :pt-br "Pacotes")
 (:nav-trails :en "Trails" :pt-br "Trilhas")
 (:nav-about :en "About" :pt-br "Sobre")
 (:nav-main :en "Main" :pt-br "Principal")
 (:other-language :en "Português" :pt-br "English")
 (:other-language-code :en "pt-BR" :pt-br "en")
 (:other-language-short :en "PT" :pt-br "EN")
 (:packages :en "Packages" :pt-br "Pacotes")
 (:package :en "Package" :pt-br "Pacote")
 (:package-count-sbcl :en "~D symbols · SBCL" :pt-br "~D símbolos · SBCL")
 (:package-count-system :en "~D symbols · ~A ~A" :pt-br "~D símbolos · ~A ~A")
 (:symbol-count :en "~D symbols." :pt-br "~D símbolos.")
 (:system-note :en "Documentation from ~A ~A, licensed ~A." :pt-br "Documentação de ~A ~A, sob licença ~A.")
 (:summary :en "Summary" :pt-br "Resumo")
 (:hyperspec :en "HyperSpec" :pt-br "HyperSpec")
 (:no-docstring :en "No documentation string is available in the implementation."
                :pt-br "A implementação não traz documentação para este símbolo.")
 (:examples :en "Examples" :pt-br "Exemplos")
 (:example-n :en "Example ~D" :pt-br "Exemplo ~D")
 (:example-by :en " · by " :pt-br " · por ")
 (:no-examples :en "No examples yet." :pt-br "Ainda não há exemplos.")
 (:examples-note :en "Examples are dedicated to the public domain (CC0 1.0) and checked by running them in SBCL."
                 :pt-br "Os exemplos são dedicados ao domínio público (CC0 1.0) e verificados executando-os no SBCL.")
 (:see-also :en "See also" :pt-br "Veja também")
 (:contribute :en "Contribute" :pt-br "Contribua")
 (:contribute-text :en "Have a better example? Add it with a pull request. It is checked automatically and reviewed before it appears here."
                   :pt-br "Tem um exemplo melhor? Envie por pull request. Ele é verificado automaticamente e revisado antes de aparecer aqui.")
 (:contribute-button :en "Add an example" :pt-br "Adicionar um exemplo")
 (:contribute-guide :en "How it works" :pt-br "Como funciona")
 (:community :en "Community" :pt-br "Comunidade")
 (:footer-hyperspec :en "The Common Lisp HyperSpec is copyright LispWorks Ltd. CLDocs links to it and never copies its text or images."
                    :pt-br "O Common Lisp HyperSpec é protegido por direitos autorais da LispWorks Ltd. O CLDocs apenas aponta para ele e nunca copia seu texto ou suas imagens.")
 (:footer-docstrings :en "Docstrings come from the documented implementation under its own license. "
                     :pt-br "As docstrings vêm da implementação documentada, sob a licença dela. ")
 (:licensing-details :en "Licensing details" :pt-br "Detalhes de licenciamento")
 (:contribution-terms :en "Contribution terms" :pt-br "Termos de contribuição")
 (:toolchain-note :en "Data extracted with SBCL ~A, Quicklisp dist ~A." :pt-br "Dados extraídos com SBCL ~A, dist do Quicklisp ~A.")
 (:not-found :en "Not found" :pt-br "Não encontrado")
 (:not-found-text :en "No such page. Try the search box above." :pt-br "Página inexistente. Tente a busca acima.")
 (:about :en "About" :pt-br "Sobre")
 (:licensing :en "Licensing" :pt-br "Licenciamento")
 (:about-hyperspec-heading :en "Common Lisp HyperSpec" :pt-br "Common Lisp HyperSpec")
 (:about-hyperspec :en " Each HyperSpec button on a symbol page leads to the official copy hosted by LispWorks."
                   :pt-br " Cada botão HyperSpec de uma página de símbolo leva à cópia oficial hospedada pela LispWorks.")
 (:about-docstrings-heading :en "Signatures and documentation strings" :pt-br "Assinaturas e docstrings")
 (:about-docstrings :en "Extracted by introspection from SBCL, which is in the public domain apart from some files under BSD-style licenses. Library docstrings keep the license of their system, shown on each page."
                    :pt-br "Extraídas por introspecção do SBCL, que é de domínio público, exceto alguns arquivos sob licenças estilo BSD. As docstrings das bibliotecas mantêm a licença do respectivo sistema, indicada em cada página.")
 (:about-examples-heading :en "Examples" :pt-br "Exemplos")
 (:about-examples :en "Examples written for CLDocs are dedicated to the public domain under CC0 1.0. Each one is executed in SBCL by the test suite and its printed results are checked."
                  :pt-br "Os exemplos escritos para o CLDocs são dedicados ao domínio público sob CC0 1.0. Cada um é executado no SBCL pelo conjunto de testes e seus resultados impressos são conferidos.")
 (:about-translations-heading :en "Translations" :pt-br "Traduções")
 (:about-translations :en "Summaries and interface text are available in English and Brazilian Portuguese. Translations are welcome as pull requests."
                      :pt-br "Resumos e textos da interface estão disponíveis em inglês e em português do Brasil. Traduções são bem-vindas por pull request.")
 (:terms :en "Contribution terms" :pt-br "Termos de contribuição")
 (:terms-version :en "Version ~A" :pt-br "Versão ~A")
 (:terms-give-heading :en "What you give" :pt-br "O que você cede")
 (:terms-give :en "Anything you contribute, an example or a translation, is dedicated to the public domain under CC0 1.0. You must be the author, or have the right to dedicate it. Do not submit code or text copied from the HyperSpec, from books or from projects whose license forbids it."
              :pt-br "Tudo o que você contribui, um exemplo ou uma tradução, é dedicado ao domínio público sob CC0 1.0. Você deve ser o autor ou ter o direito de dedicá-lo. Não envie código ou texto copiado do HyperSpec, de livros ou de projetos cuja licença proíba isso.")
 (:terms-review-heading :en "Review" :pt-br "Revisão")
 (:terms-review :en "Contributions arrive as pull requests. A maintainer reviews every one, and a check runs your examples before anything is published. Spam, advertising, abusive, misleading, unsafe or off-topic contributions are declined or removed."
                :pt-br "As contribuições chegam por pull request. Uma pessoa mantenedora revisa todas, e uma verificação executa seus exemplos antes de qualquer publicação. Spam, propaganda, conteúdo abusivo, enganoso, inseguro ou fora do tema é recusado ou removido.")
 (:terms-limits-heading :en "Limits" :pt-br "Limites")
 (:terms-limits :en "A contributed file holds at most four examples and 8000 characters. Examples must not run programs, use the network or touch files outside /tmp/cldocs-*."
                :pt-br "Um arquivo contribuído tem no máximo quatro exemplos e 8000 caracteres. Os exemplos não podem executar programas, usar a rede nem tocar arquivos fora de /tmp/cldocs-*.")
 (:terms-data-heading :en "Your data" :pt-br "Seus dados")
 (:terms-data :en "Your GitHub login is recorded in the file you contribute and in the repository history, both public. CLDocs sets no cookies and runs no analytics."
              :pt-br "Seu login do GitHub fica registrado no arquivo que você contribui e no histórico do repositório, ambos públicos. O CLDocs não define cookies nem usa analytics.")
 (:terms-back-heading :en "Taking things back" :pt-br "Retirando contribuições")
 (:terms-back :en "Open a pull request or an issue to have a contribution removed. Because contributions are public domain, copies others already made stay theirs."
              :pt-br "Abra um pull request ou uma issue para remover uma contribuição. Como as contribuições são de domínio público, cópias que outras pessoas já fizeram continuam delas.")
 (:trails :en "Trails" :pt-br "Trilhas")
 (:trails-lede :en "Guided paths through Common Lisp by theme, from the basics to the corners of each topic."
               :pt-br "Caminhos guiados pelo Common Lisp, por tema, do básico aos cantos de cada assunto.")
 (:trail-count :en "~D symbols" :pt-br "~D símbolos")
 (:trail :en "Trail" :pt-br "Trilha")
 (:kind-function :en "Function" :pt-br "Função")
 (:kind-generic-function :en "Generic function" :pt-br "Função genérica")
 (:kind-macro :en "Macro" :pt-br "Macro")
 (:kind-special-operator :en "Special operator" :pt-br "Operador especial")
 (:kind-variable :en "Variable" :pt-br "Variável")
 (:kind-constant :en "Constant" :pt-br "Constante")
 (:kind-class :en "Class" :pt-br "Classe")
 (:kind-condition :en "Condition" :pt-br "Condição")
 (:kind-type :en "Type" :pt-br "Tipo")
 (:kind-symbol :en "Symbol" :pt-br "Símbolo")
)
