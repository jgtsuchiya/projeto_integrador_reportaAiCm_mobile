// Roda no pre-commit, só com o que está staged: o lint-staged esconde as mudanças fora do commit
// enquanto as tarefas rodam. Os comandos passam pelo FVM, para usar a versão do Flutter do .fvmrc.
const quote = (files) => files.map((file) => `"${file}"`).join(' ');

export default {
  // O analyzer confere o projeto inteiro: uma mudança num arquivo pode quebrar outro. Ele também
  // roda quando muda o pubspec.yaml ou o analysis_options.yaml.
  '*.{dart,yaml}': (files) => {
    const dartFiles = files.filter((file) => file.endsWith('.dart'));

    return [
      ...(dartFiles.length > 0 ? [`fvm dart format ${quote(dartFiles)}`] : []),
      'fvm flutter analyze --fatal-infos',
    ];
  },
};
