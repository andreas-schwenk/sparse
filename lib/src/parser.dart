/// sparse - a simple parser
/// (c) 2023 by Andreas Schwenk <mailto:contact@compiler-construction.com>
/// License: GPL-3.0-or-later

import 'package:slex/slex.dart';

import 'grammar.dart';

class ParseTreeNode {
  bool isOption = false;
  bool isRepetition = false;
  bool isSequence = false;
  bool isNonTerminal = false;
  String ruleID;
  String alias = '';
  LexerToken? token;
  List<ParseTreeNode> subNodes = [];
  String nonTerminalId = '';

  ParseTreeNode(this.ruleID, this.token);

  String getTerminal(String alias) {
    for (var n in subNodes) {
      if (n.token != null && n.alias == alias) {
        return (n.token as LexerToken).token;
      }
    }
    return '';
  }

  List<String> getTerminals() {
    List<String> t = [];
    for (var n in subNodes) {
      if (n.token != null) {
        var tk = n.token as LexerToken;
        t.add(tk.token);
      } else {
        t.addAll(n.getTerminals());
      }
    }
    return t;
  }

  ParseTreeNode? getNonTerminal(String alias) {
    for (var n in subNodes) {
      if (n.isNonTerminal && n.alias == alias) {
        return n;
      }
    }
    return null;
  }

  bool isOptionNonempty(String alias) {
    for (var n in subNodes) {
      if (n.isOption && n.alias == alias) {
        return n.subNodes.isNotEmpty;
      }
    }
    return false;
  }

  ParseTreeNode? getOption(String alias) {
    for (var n in subNodes) {
      if (n.isOption && n.alias == alias && n.subNodes.isNotEmpty) {
        return n.subNodes[0];
      }
    }
    return null;
  }

  @override
  String toString([int indent = 0]) {
    var s = '';
    for (var i = 0; i < indent; i++) {
      s += '  ';
    }
    if (isOption) {
      s += '[OPTION]';
    } else if (isRepetition) {
      s += '[REPETITION]';
    } else if (isSequence) {
      s += '[SEQUENCE]';
    } else if (isNonTerminal) {
      s += '$nonTerminalId[NON-TERMINAL]';
    } else if (token != null) {
      var t = token as LexerToken;
      s += '${t.type.name.toUpperCase()}:${t.row}:${t.col}:${t.token}';
    }
    s += '\n';
    if (s.trim().isEmpty) {
      var bp = 1337;
    }
    for (var n in subNodes) {
      s += n.toString(indent + 1);
    }
    return s;
  }
}

class Parser {
  Lexer _lex = Lexer();
  final Grammar _grammar;
  LexerToken _rightMostParsedToken = LexerToken();
  ParseTreeNode? _parseTree;
  void Function(ParseTreeNode n) callback;

  Parser(this._grammar, this.callback);

  ParseTreeNode? get parseTree {
    return _parseTree;
  }

  bool parse(String src) {
    if (_grammar.rules.isEmpty) {
      throw Exception('no rules');
    }
    _lex = Lexer();
    _lex.pushSource('SRC', src);
    try {
      _rightMostParsedToken = _lex.getToken();
      var rule = _grammar.rules[0];
      _parseTree = _parseRuleNode(rule, rule.rootNode, true);
      if (_parseTree == null) {
        _lex.error("unexpected '${_rightMostParsedToken.token}'",
            _rightMostParsedToken);
        return false;
      }
    } catch (e) {
      print(e);
      return false;
    }
    return true;
  }

  ParseTreeNode? _parseRuleNode(Rule rule, RuleNode node,
      [bool ruleRootCall = false]) {
    var tk = _lex.getToken();
    print("$tk: _parseRuleNode(${rule.id},$node)");
    if (tk.row > _rightMostParsedToken.row) {
      _rightMostParsedToken = tk;
    } else if (tk.row == _rightMostParsedToken.row &&
        tk.col > _rightMostParsedToken.col) {
      _rightMostParsedToken = tk;
    }
    switch (node.type) {
      case RuleNodeType.alternatives:
        {
          // TODO: accelerate with FIRST set
          ParseTreeNode? ptn;
          for (var n in node.subNodes) {
            var bak = _lex.backupState();
            ptn = _parseRuleNode(rule, n);
            if (ptn != null) {
              //ptn.root = ruleRootCall;
              break;
            }
            _lex.replayState(bak);
          }
          return ptn;
        }
      case RuleNodeType.sequence:
        {
          var ptn = ParseTreeNode(rule.id, null);
          ptn.isSequence = true;
          for (var n in node.subNodes) {
            var subPtn = _parseRuleNode(rule, n);
            if (subPtn == null) {
              return null;
            } else {
              ptn.subNodes.add(subPtn);
            }
          }
          return ptn.subNodes.length == 1 ? ptn.subNodes[0] : ptn;
        }
      case RuleNodeType.option:
        {
          var ptn = ParseTreeNode(rule.id, null);
          ptn.alias = node.alias;
          ptn.isOption = true;
          var bak = _lex.backupState();
          var subPtn = _parseRuleNode(rule, node.subNodes[0]);
          if (subPtn == null) {
            _lex.replayState(bak);
          } else {
            ptn.subNodes.add(subPtn);
          }
          return ptn;
        }
      case RuleNodeType.repetition:
        {
          var ptn = ParseTreeNode(rule.id, null);
          ptn.alias = node.alias;
          ptn.isRepetition = true;
          while (true) {
            var bak = _lex.backupState();
            var subPtn = _parseRuleNode(rule, node.subNodes[0]);
            if (subPtn == null) {
              _lex.replayState(bak);
              break;
            } else {
              ptn.subNodes.add(subPtn);
            }
          }
          return ptn;
        }
      case RuleNodeType.identifier:
        {
          if (_lex.isIdentifier()) {
            var ptn = ParseTreeNode(rule.id, _lex.getToken());
            ptn.alias = node.alias;
            _lex.identifier();
            return ptn;
          }
          return null;
        }
      case RuleNodeType.integer:
        {
          if (_lex.isInteger()) {
            var ptn = ParseTreeNode(rule.id, _lex.getToken());
            ptn.alias = node.alias;
            _lex.integer();
            return ptn;
          }
          return null;
        }
      case RuleNodeType.real:
        {
          if (_lex.isRealNumber()) {
            var ptn = ParseTreeNode(rule.id, _lex.getToken());
            ptn.alias = node.alias;
            _lex.realNumber();
            return ptn;
          }
          return null;
        }
      case RuleNodeType.string:
        {
          if (_lex.isString()) {
            var ptn = ParseTreeNode(rule.id, _lex.getToken());
            ptn.alias = node.alias;
            _lex.string();
            return ptn;
          }
          return null;
        }
      case RuleNodeType.end:
        {
          if (_lex.isEnd()) {
            var ptn = ParseTreeNode(rule.id, _lex.getToken());
            ptn.alias = node.alias;
            _lex.end();
            return ptn;
          }
          return null;
        }
      case RuleNodeType.terminal:
        {
          if (_lex.isTerminal(node.value)) {
            var ptn = ParseTreeNode(rule.id, _lex.getToken());
            ptn.alias = node.alias;
            _lex.terminal(node.value);
            return ptn;
          }
          return null;
        }
      case RuleNodeType.nonTerminal:
        {
          var ptn = ParseTreeNode(rule.id, null);
          ptn.alias = node.alias;
          ptn.isNonTerminal = true;
          var nonTerminalRule = node.nonTerminalRef as Rule;
          ptn.nonTerminalId = nonTerminalRule.id;
          var ptnSub =
              _parseRuleNode(nonTerminalRule, nonTerminalRule.rootNode, true);
          if (ptnSub == null) {
            return null;
          } else {
            ptn.subNodes.add(ptnSub);
            callback(ptnSub);
          }
          return ptn;
        }
    }
  }
}
