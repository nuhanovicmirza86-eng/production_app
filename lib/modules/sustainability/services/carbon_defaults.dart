import '../models/carbon_models.dart';

/// Početni faktori (proxy; administrator ih može prepisati u Firestore).
/// Izvori: UNFCCC grid BA + UK GHG Conversion Factors 2025 (kao u Excel predlošku).
class CarbonDefaults {
  CarbonDefaults._();

  static List<CarbonEmissionFactor> defaultFactors() {
    return const [
      CarbonEmissionFactor(
        factorKey: 'BA_2026_ELEC_GRID_KWH',
        scope: '2',
        category: 'Electricity',
        activity: 'Grid electricity',
        unit: 'kWh',
        factorKgCo2ePerUnit: 0.738997,
        sourceName: 'UNFCCC Harmonized Grid Emission Factor dataset',
        sourceUrl:
            'https://unfccc.int/sites/default/files/resource/Harmonized_Grid_Emission_factor_data_set.xlsx',
        factorStatus: 'proxy',
      ),
      CarbonEmissionFactor(
        factorKey: 'BA_2025_FUEL_NATGAS_M3',
        scope: '1',
        category: 'Fuel',
        activity: 'Natural gas',
        unit: 'm3',
        factorKgCo2ePerUnit: 2.06672,
        sourceName: 'UK Government GHG Conversion Factors 2025',
        sourceUrl:
            'https://www.gov.uk/government/publications/greenhouse-gas-reporting-conversion-factors-2025',
        factorStatus: 'proxy',
      ),
      CarbonEmissionFactor(
        factorKey: 'BA_2025_FUEL_DIESEL_L',
        scope: '1',
        category: 'Fuel',
        activity: 'Diesel forecourt',
        unit: 'litres',
        factorKgCo2ePerUnit: 2.57082,
        sourceName: 'UK Government GHG Conversion Factors 2025',
        sourceUrl:
            'https://www.gov.uk/government/publications/greenhouse-gas-reporting-conversion-factors-2025',
        factorStatus: 'proxy',
      ),
      CarbonEmissionFactor(
        factorKey: 'BA_2025_FUEL_PETROL_L',
        scope: '1',
        category: 'Fuel',
        activity: 'Petrol forecourt',
        unit: 'litres',
        factorKgCo2ePerUnit: 2.06916,
        sourceName: 'UK Government GHG Conversion Factors 2025',
        sourceUrl:
            'https://www.gov.uk/government/publications/greenhouse-gas-reporting-conversion-factors-2025',
        factorStatus: 'proxy',
      ),
      CarbonEmissionFactor(
        factorKey: 'BA_2025_FUEL_LPG_L',
        scope: '1',
        category: 'Fuel',
        activity: 'LPG',
        unit: 'litres',
        factorKgCo2ePerUnit: 1.55,
        sourceName: 'UK Government GHG Conversion Factors 2025 (proxy)',
        sourceUrl:
            'https://www.gov.uk/government/publications/greenhouse-gas-reporting-conversion-factors-2025',
        factorStatus: 'proxy',
      ),
      CarbonEmissionFactor(
        factorKey: 'BA_2025_TRAVEL_CAR_DIESEL_KM',
        scope: '3',
        category: 'Business travel',
        activity: 'Average car diesel',
        unit: 'km',
        factorKgCo2ePerUnit: 0.171,
        sourceName: 'UK Government GHG Conversion Factors 2025',
        sourceUrl:
            'https://www.gov.uk/government/publications/greenhouse-gas-reporting-conversion-factors-2025',
        factorStatus: 'proxy',
      ),
      CarbonEmissionFactor(
        factorKey: 'BA_2025_TRAVEL_CAR_PETROL_KM',
        scope: '3',
        category: 'Business travel',
        activity: 'Average car petrol',
        unit: 'km',
        factorKgCo2ePerUnit: 0.18,
        sourceName: 'UK Government GHG Conversion Factors 2025',
        sourceUrl:
            'https://www.gov.uk/government/publications/greenhouse-gas-reporting-conversion-factors-2025',
        factorStatus: 'proxy',
      ),
      CarbonEmissionFactor(
        factorKey: 'BA_2025_FREIGHT_VAN_KM',
        scope: '3',
        category: 'Freight',
        activity: 'Van average diesel',
        unit: 'km',
        factorKgCo2ePerUnit: 0.25,
        sourceName: 'UK Government GHG Conversion Factors 2025',
        sourceUrl:
            'https://www.gov.uk/government/publications/greenhouse-gas-reporting-conversion-factors-2025',
        factorStatus: 'proxy',
      ),
      CarbonEmissionFactor(
        factorKey: 'BA_2025_FREIGHT_HGV_TKM',
        scope: '3',
        category: 'Freight',
        activity: 'HGV all diesel',
        unit: 'tonne.km',
        factorKgCo2ePerUnit: 0.12226,
        sourceName: 'UK Government GHG Conversion Factors 2025',
        sourceUrl:
            'https://www.gov.uk/government/publications/greenhouse-gas-reporting-conversion-factors-2025',
        factorStatus: 'proxy',
      ),
      CarbonEmissionFactor(
        factorKey: 'BA_2025_TRAVEL_FLIGHT_SHORT_PKM',
        scope: '3',
        category: 'Business travel',
        activity: 'Flight short-haul avg passenger',
        unit: 'passenger.km',
        factorKgCo2ePerUnit: 0.155,
        sourceName: 'UK Government GHG Conversion Factors 2025',
        sourceUrl:
            'https://www.gov.uk/government/publications/greenhouse-gas-reporting-conversion-factors-2025',
        factorStatus: 'proxy',
      ),
      CarbonEmissionFactor(
        factorKey: 'BA_2025_TRAVEL_FLIGHT_LONG_PKM',
        scope: '3',
        category: 'Business travel',
        activity: 'Flight long-haul avg passenger',
        unit: 'passenger.km',
        factorKgCo2ePerUnit: 0.11,
        sourceName: 'UK Government GHG Conversion Factors 2025',
        sourceUrl:
            'https://www.gov.uk/government/publications/greenhouse-gas-reporting-conversion-factors-2025',
        factorStatus: 'proxy',
      ),
      CarbonEmissionFactor(
        factorKey: 'BA_2025_WATER_SUPPLY_M3',
        scope: '3',
        category: 'Water',
        activity: 'Water supply',
        unit: 'm3',
        factorKgCo2ePerUnit: 0.149,
        sourceName: 'UK Government GHG Conversion Factors 2025',
        sourceUrl:
            'https://www.gov.uk/government/publications/greenhouse-gas-reporting-conversion-factors-2025',
        factorStatus: 'proxy',
      ),
      CarbonEmissionFactor(
        factorKey: 'BA_2025_WATER_TREATMENT_M3',
        scope: '3',
        category: 'Water',
        activity: 'Water treatment',
        unit: 'm3',
        factorKgCo2ePerUnit: 0.272,
        sourceName: 'UK Government GHG Conversion Factors 2025',
        sourceUrl:
            'https://www.gov.uk/government/publications/greenhouse-gas-reporting-conversion-factors-2025',
        factorStatus: 'proxy',
      ),
      CarbonEmissionFactor(
        factorKey: 'BA_2025_WASTE_PAPER_LANDFILL_T',
        scope: '3',
        category: 'Waste',
        activity: 'Paper landfill',
        unit: 'tonnes',
        factorKgCo2ePerUnit: 498.0,
        sourceName: 'UK Government GHG Conversion Factors 2025',
        sourceUrl:
            'https://www.gov.uk/government/publications/greenhouse-gas-reporting-conversion-factors-2025',
        factorStatus: 'proxy',
      ),
      CarbonEmissionFactor(
        factorKey: 'BA_2025_WASTE_METAL_RECYCLE_T',
        scope: '3',
        category: 'Waste',
        activity: 'Metal recycle',
        unit: 'tonnes',
        factorKgCo2ePerUnit: 21.0,
        sourceName: 'UK Government GHG Conversion Factors 2025',
        sourceUrl:
            'https://www.gov.uk/government/publications/greenhouse-gas-reporting-conversion-factors-2025',
        factorStatus: 'proxy',
      ),
      CarbonEmissionFactor(
        factorKey: 'BA_2025_WASTE_PLASTIC_RECYCLE_T',
        scope: '3',
        category: 'Waste',
        activity: 'Plastic recycle',
        unit: 'tonnes',
        factorKgCo2ePerUnit: 49.0,
        sourceName: 'UK Government GHG Conversion Factors 2025',
        sourceUrl:
            'https://www.gov.uk/government/publications/greenhouse-gas-reporting-conversion-factors-2025',
        factorStatus: 'proxy',
      ),
      CarbonEmissionFactor(
        factorKey: 'BA_2025_WASTE_FOOD_LANDFILL_T',
        scope: '3',
        category: 'Waste',
        activity: 'Food landfill',
        unit: 'tonnes',
        factorKgCo2ePerUnit: 605.0,
        sourceName: 'UK Government GHG Conversion Factors 2025',
        sourceUrl:
            'https://www.gov.uk/government/publications/greenhouse-gas-reporting-conversion-factors-2025',
        factorStatus: 'proxy',
      ),
    ];
  }

  static Map<String, CarbonEmissionFactor> defaultFactorMap() {
    final m = <String, CarbonEmissionFactor>{};
    for (final f in defaultFactors()) {
      m[f.factorKey] = f;
    }
    return m;
  }
}
