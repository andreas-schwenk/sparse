/// sparse - a simple parser
/// (c) 2023 by Andreas Schwenk <mailto:contact@compiler-construction.com>
/// License: GPL-3.0-or-later

import 'package:sparse/src/generator.dart';
import 'package:sparse/src/parser.dart';

void main() {
  // TODO: configure lexer
  String grammar = '''
// === Dart Grammar ===
file = { fileItem } END;
fileItem = enum | class | function;
enum = "enum" ID "{" enumItem { "," enumItem } [";"] "}";
enumItem = ID;
class = "class" ID "{" {classItem} "}";
classItem = attribute | function;
attribute = ["static"|"final"] type ID [ "=" expr ] ";";
function = type@t ID@id "(" [parameters]@p ")" block@b;
type = "void" | "bool" | "int" | "double" | "number" | "String"
  | "List" "<" type ">"
  | "Map" "<" type "," type ">"
  | ID /*@class.ID*/;
parameters = parameter { "," parameter };
parameter = type ID;
block = statement | "{" {statement} "}";
statement = declaration | while | for | if | return 
  | continue | break | expr ";";
declaration = type ID "=" expr ";";
continue = "continue";
break = "break";
while = "while" "(" expr ")" block;
for = "for" "(" "var" ID "in" expr ")"
  | "for" "(" [expr] ";" [expr] ";" [expr] ")";
if = "if" "(" expr ")" block 
    { "else" "if" "(" expr ")" block } 
    [ "else" block ];
return = "return" [ expr ] ";";
expr = add [ ("="|"+=") expr ];
add = mul { ("+"|"-") mul };
mul = unary { ("*"|"/"|"%") unary };
unary = INT | REAL | ID [ "(" [args] ")" ] 
  | "(" expr ")" | STR | "-" unary;
args = expr { "," expr };
''';
  var pg = ParserGenerator();
  if (pg.generate(grammar) == false) {
    print("ERRORS OCCURRED!");
    return;
  }
  print(pg.toString());

  var src = '''
int add(int x, int y) {
  return x + y;
}

void main() {
  var x = 3*2 + 5;
  var y = add(11, 12);
  print("hello, world!");
}
''';
  var parser = Parser(pg.grammar, callback);
  if (parser.parse(src)) {
    print(parser.parseTree);
  } else {
    print("ERROR: parsing failed!");
  }
}

void callback(ParseTreeNode n) {
  switch (n.ruleID) {
    case "function":
      {
        var id = n.getTerminal('id');
        var type = n.getNonTerminal('t');
        var typeTerminals = type?.getTerminals();
        if (n.isOptionNonempty('p')) {
          var parameters = n.getOption('p');
        }
        var block = n.getNonTerminal('b');
        break;
      }
    case "type":
      {
        var bp = 1337;
        break;
      }
    default:
      break;
  }
}
