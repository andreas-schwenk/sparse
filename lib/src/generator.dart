/// sparse - a simple parser
/// (c) 2023 by Andreas Schwenk <mailto:contact@compiler-construction.com>
/// License: GPL-3.0-or-later

import 'package:slex/slex.dart';

import 'grammar.dart';

class ParserGenerator {
  Lexer _lex = Lexer();
  Grammar _grammar = Grammar();

  Grammar get grammar {
    return _grammar;
  }

  bool generate(String grammarSrc) {
    _grammar = Grammar();
    _lex = Lexer();
    _lex.configureSingleLineComments("//");
    _lex.configureMultiLineComments("/*", "*/");
    try {
      _lex.pushSource('GRAMMAR', grammarSrc);
      // TODO: check, if root rule has "END" token at end.
      while (_lex.isNotEnd()) {
        _parseRule();
      }
      _grammar.resolveNonTerminals();
    } catch (e) {
      print("ParserGenerator.generate(..) failed!");
      print(e);
      return false;
    }
    return true;
  }

  //G rule = ID "=" alternatives ";";
  void _parseRule() {
    var id = _lex.identifier();
    _lex.terminal("=");
    var node = _parseAlternatives();
    _lex.terminal(";");
    var rule = Rule(id, node);
    // TODO: must check, if rule with same name does NOT exist
    _grammar.rules.add(rule);
  }

  //G alternatives = sequence { "|" sequence };
  RuleNode _parseAlternatives() {
    RuleNode node = RuleNode(RuleNodeType.alternatives);
    node.subNodes.add(_parseSequence());
    while (_lex.isTerminal("|")) {
      _lex.next();
      node.subNodes.add(_parseSequence());
    }
    if (node.subNodes.length == 1) return node.subNodes[0];
    return node;
  }

  //G sequence = { item };
  RuleNode _parseSequence() {
    RuleNode node = RuleNode(RuleNodeType.sequence);
    while (_lex.isNotTerminal("|") &&
        _lex.isNotTerminal(";") &&
        _lex.isNotTerminal("}") &&
        _lex.isNotTerminal("]") &&
        _lex.isNotTerminal(")")) {
      node.subNodes.add(_parseItem());
    }
    if (node.subNodes.length == 1) return node.subNodes[0];
    return node;
  }

  //G item = "ID" | "INT" | "REAL" | "STR" | "END" | STR | ID |
  //    | "{" alternatives "}"
  //    | "[" alternatives "]" | "(" alternatives ")";
  RuleNode _parseItem() {
    if (_lex.isTerminal("ID")) {
      _lex.next();
      return RuleNode(RuleNodeType.identifier);
    } else if (_lex.isTerminal("INT")) {
      _lex.next();
      return RuleNode(RuleNodeType.integer);
    } else if (_lex.isTerminal("REAL")) {
      _lex.next();
      return RuleNode(RuleNodeType.real);
    } else if (_lex.isTerminal("STR")) {
      _lex.next();
      return RuleNode(RuleNodeType.string);
    } else if (_lex.isTerminal("END")) {
      _lex.next();
      return RuleNode(RuleNodeType.end);
    } else if (_lex.isIdentifier()) {
      var id = _lex.identifier();
      var node = RuleNode(RuleNodeType.nonTerminal);
      node.value = id;
      return node;
    } else if (_lex.isString()) {
      var str = _lex.string();
      var node = RuleNode(RuleNodeType.terminal);
      node.value = str;
      return node;
    } else if (_lex.isTerminal("{")) {
      var node = RuleNode(RuleNodeType.repetition);
      _lex.next();
      node.subNodes.add(_parseAlternatives());
      _lex.terminal("}");
      return node;
    } else if (_lex.isTerminal("[")) {
      var node = RuleNode(RuleNodeType.option);
      _lex.next();
      node.subNodes.add(_parseAlternatives());
      _lex.terminal("]");
      return node;
    } else if (_lex.isTerminal("(")) {
      _lex.next();
      var node = _parseAlternatives();
      _lex.terminal(")");
      return node;
    } else {
      _lex.error("expected rule item, but got '${_lex.getToken().token}'");
      throw Exception();
    }
  }

  @override
  String toString() {
    return _grammar.toString();
  }
}
