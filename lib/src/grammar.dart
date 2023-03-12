/// sparse - a simple parser
/// (c) 2023 by Andreas Schwenk <mailto:contact@compiler-construction.com>
/// License: GPL-3.0-or-later

// TODO: code doc

enum RuleNodeType {
  alternatives,
  end,
  identifier,
  integer,
  nonTerminal,
  option,
  real,
  repetition,
  sequence,
  string,
  terminal,
}

class RuleNode {
  RuleNodeType type;
  List<RuleNode> subNodes = [];
  String value = '';
  Rule? nonTerminalRef;
  String alias = '';

  RuleNode(this.type);

  void resolveNonTerminals(Grammar grammar) {
    if (type == RuleNodeType.nonTerminal) {
      nonTerminalRef = grammar.getRuleById(value);
      if (nonTerminalRef == null) {
        throw Exception("referred to non-existent rule '$value'");
      }
    }
    for (var n in subNodes) {
      n.resolveNonTerminals(grammar);
    }
  }

  @override
  String toString() {
    var s = '';
    switch (type) {
      case RuleNodeType.alternatives:
        s = '(';
        for (var n in subNodes) {
          if (s.length > 1) s += ' | ';
          s += n.toString();
        }
        s += ')';
        break;
      case RuleNodeType.sequence:
        for (var n in subNodes) {
          if (s.length > 1) s += ' ';
          s += n.toString();
        }
        break;
      case RuleNodeType.nonTerminal:
        s += value;
        break;
      case RuleNodeType.terminal:
        s += "\"$value\"";
        break;
      case RuleNodeType.identifier:
        s += "ID";
        break;
      case RuleNodeType.integer:
        s += "INT";
        break;
      case RuleNodeType.real:
        s += "REAL";
        break;
      case RuleNodeType.string:
        s += "STR";
        break;
      case RuleNodeType.end:
        s += "END";
        break;
      case RuleNodeType.option:
        s += "[ ${subNodes[0]} ]";
        break;
      case RuleNodeType.repetition:
        s += "{ ${subNodes[0]} }";
        break;
    }
    return s;
  }
}

class Rule {
  String id = '';
  RuleNode rootNode;

  Rule(this.id, this.rootNode);

  void resolveNonTerminals(Grammar grammar) {
    rootNode.resolveNonTerminals(grammar);
  }

  @override
  String toString() {
    return '$id = $rootNode;';
  }
}

class Grammar {
  List<Rule> rules = [];

  void resolveNonTerminals() {
    for (var rule in rules) {
      rule.resolveNonTerminals(this);
    }
  }

  Rule? getRuleById(String id) {
    for (var rule in rules) {
      if (rule.id == id) {
        return rule;
      }
    }
    return null;
  }

  @override
  String toString() {
    var s = 'rules:\n';
    for (var rule in rules) {
      s += '  $rule\n';
    }
    return s;
  }
}
