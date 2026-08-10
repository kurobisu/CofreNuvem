import 'package:flutter/material.dart';

class BancoLogo {
  final String codigo;
  final String nome;
  final String colorHex;
  final IconData? iconData; // Optional, if we want specific icons

  const BancoLogo({
    required this.codigo,
    required this.nome,
    required this.colorHex,
    this.iconData,
  });
}

class BancosBrasil {
  static const List<BancoLogo> bancos = [
    BancoLogo(codigo: '001', nome: 'Banco do Brasil', colorHex: '#F9D000'),
    BancoLogo(codigo: '033', nome: 'Santander', colorHex: '#EC0000'),
    BancoLogo(codigo: '104', nome: 'Caixa Econômica', colorHex: '#005CA9'),
    BancoLogo(codigo: '237', nome: 'Bradesco', colorHex: '#CC092F'),
    BancoLogo(codigo: '341', nome: 'Itaú', colorHex: '#EC7000'),
    BancoLogo(codigo: '077', nome: 'Banco Inter', colorHex: '#FF7A00'),
    BancoLogo(codigo: '260', nome: 'Nubank', colorHex: '#8A05BE'),
    BancoLogo(codigo: '336', nome: 'C6 Bank', colorHex: '#242424'),
    BancoLogo(codigo: '212', nome: 'Banco Original', colorHex: '#00C853'),
    BancoLogo(codigo: '074', nome: 'Banco BMG', colorHex: '#FFA500'),
    BancoLogo(codigo: '655', nome: 'Neon', colorHex: '#00A4CA'),
    BancoLogo(codigo: '100', nome: 'Dinheiro Físico/Caixa', colorHex: '#4CAF50', iconData: Icons.money),
    BancoLogo(codigo: '999', nome: 'Outro', colorHex: '#9E9E9E', iconData: Icons.account_balance),
  ];

  static BancoLogo obterBancoPorCodigo(String codigo) {
    return bancos.firstWhere((b) => b.codigo == codigo, orElse: () => bancos.last);
  }
}
