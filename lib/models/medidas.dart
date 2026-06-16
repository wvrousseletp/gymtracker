class BodyMeasurement {
  final String id;
  final String date; // YYYY-MM-DD
  final double peso;
  final double gordura;
  final double pescoco;
  final double ombros;
  final double peito;
  final double cintura;
  final double quadril;
  final double bracoEsq;
  final double bracoDir;
  final double coxaEsq;
  final double coxaDir;
  final double panturrilhaEsq;
  final double panturrilhaDir;

  BodyMeasurement({
    required this.id,
    required this.date,
    required this.peso,
    required this.gordura,
    required this.pescoco,
    required this.ombros,
    required this.peito,
    required this.cintura,
    required this.quadril,
    required this.bracoEsq,
    required this.bracoDir,
    required this.coxaEsq,
    required this.coxaDir,
    required this.panturrilhaEsq,
    required this.panturrilhaDir,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'peso': peso,
    'gordura': gordura,
    'pescoco': pescoco,
    'ombros': ombros,
    'peito': peito,
    'cintura': cintura,
    'quadril': quadril,
    'braco_esq': bracoEsq,
    'braco_dir': bracoDir,
    'coxa_esq': coxaEsq,
    'coxa_dir': coxaDir,
    'panturrilha_esq': panturrilhaEsq,
    'panturrilha_dir': panturrilhaDir,
  };

  factory BodyMeasurement.fromJson(Map<String, dynamic> json) => BodyMeasurement(
    id: json['id'] ?? '',
    date: json['date'] ?? '',
    peso: (json['peso'] as num?)?.toDouble() ?? 0.0,
    gordura: (json['gordura'] as num?)?.toDouble() ?? 0.0,
    pescoco: (json['pescoco'] as num?)?.toDouble() ?? 0.0,
    ombros: (json['ombros'] as num?)?.toDouble() ?? 0.0,
    peito: (json['peito'] as num?)?.toDouble() ?? 0.0,
    cintura: (json['cintura'] as num?)?.toDouble() ?? 0.0,
    quadril: (json['quadril'] as num?)?.toDouble() ?? 0.0,
    bracoEsq: (json['braco_esq'] as num?)?.toDouble() ?? 0.0,
    bracoDir: (json['braco_dir'] as num?)?.toDouble() ?? 0.0,
    coxaEsq: (json['coxa_esq'] as num?)?.toDouble() ?? 0.0,
    coxaDir: (json['coxa_dir'] as num?)?.toDouble() ?? 0.0,
    panturrilhaEsq: (json['panturrilha_esq'] as num?)?.toDouble() ?? 0.0,
    panturrilhaDir: (json['panturrilha_dir'] as num?)?.toDouble() ?? 0.0,
  );
}
