# Regras do Projeto GymTracker

- **Sempre incrementar o build number (ex: `2.1.0+66`) em `pubspec.yaml` antes de fazer `git commit` e `git push`** que ativem o pipeline de deploy para o TestFlight/App Store.
- O App Store Connect rejeita compilações com a mesma versão e build code duplicados (`ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE`). Portanto, certifique-se de obter/incrementar esse número a cada nova alteração.
