import 'package:rps/rps.dart';
import 'package:yaml/yaml.dart';

class MockedScriptSource implements ScriptsSource {
  final String pubspecContent;

  MockedScriptSource(this.pubspecContent);

  @override
  dynamic getScripts() {
    return loadYaml(pubspecContent)['scripts'];
  }
}
