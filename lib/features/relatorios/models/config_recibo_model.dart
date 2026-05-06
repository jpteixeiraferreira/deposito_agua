class ConfigRecibo {
  final String nomeEmpresa;
  final String endereco;
  final String cidade;
  final String email;
  final String telefone;
  final String logoUrl;
  final double logoTamanho;
  final String rodape;

  const ConfigRecibo({
    required this.nomeEmpresa,
    required this.endereco,
    required this.cidade,
    required this.email,
    required this.telefone,
    required this.logoUrl,
    required this.logoTamanho,
    required this.rodape,
  });

  factory ConfigRecibo.padrao() {
    return const ConfigRecibo(
      nomeEmpresa: 'DEPÓSITO PAI&FILHO - DISTRIBUIDOR DE ÁGUA',
      endereco: 'Rua Mozart Bastos Soares, 929 - Cehab - 28300-000',
      cidade: 'Itaperuna - RJ',
      email: 'distri_paieefilho@hotmail.com',
      telefone: '(022)99753-9989 (WhatsApp)',
      logoUrl: '',
      logoTamanho: 100,
      rodape: 'Identificação de assinatura de recebimento',
    );
  }

  factory ConfigRecibo.fromMap(Map<String, dynamic> map) {
    final padrao = ConfigRecibo.padrao();

    return ConfigRecibo(
      nomeEmpresa: (map['nome_empresa'] ?? padrao.nomeEmpresa).toString(),
      endereco: (map['endereco'] ?? padrao.endereco).toString(),
      cidade: (map['cidade'] ?? padrao.cidade).toString(),
      email: (map['email'] ?? padrao.email).toString(),
      telefone: (map['telefone'] ?? padrao.telefone).toString(),
      logoUrl: (map['logo_url'] ?? padrao.logoUrl).toString(),
      logoTamanho:
          double.tryParse(
            (map['logo_tamanho'] ?? padrao.logoTamanho).toString(),
          ) ??
          padrao.logoTamanho,
      rodape: (map['rodape'] ?? padrao.rodape).toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': 1,
      'nome_empresa': nomeEmpresa,
      'endereco': endereco,
      'cidade': cidade,
      'email': email,
      'telefone': telefone,
      'logo_url': logoUrl,
      'logo_tamanho': logoTamanho,
      'rodape': rodape,
    };
  }
}
