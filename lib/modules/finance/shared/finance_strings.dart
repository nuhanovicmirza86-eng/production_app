import 'package:flutter/widgets.dart';

/// Finance modul — BA (default) i EN stringovi (bez generičkog skraćivanja naziva modula).
class FinanceStrings {
  FinanceStrings._();

  static bool isEnglish(BuildContext context) {
    return Localizations.localeOf(context).languageCode == 'en';
  }

  static String t(BuildContext context, String key) {
    final en = isEnglish(context);
    final map = en ? _en : _bs;
    return map[key] ?? key;
  }

  static const _bs = <String, String>{
    'finance_hub_title': 'Finance',
    'finance_hub_subtitle':
        'Operativni novčani tok — računi, kategorije i transakcije (Callable sloj).',
    'card_accounts_title': 'Računi',
    'card_accounts_subtitle':
        'Bankovni računi, blagajne i trenutno stanje novca.',
    'card_categories_title': 'Cash Flow kategorije',
    'card_categories_subtitle':
        'Šifrarnik kategorija za operativne, investicione i finansijske tokove.',
    'module_not_enabled':
        'Modul finance_controlling nije uključen za ovu kompaniju.',
    'access_denied': 'Nemate pravo pristupa Finance modulu.',
    'accounts_title': 'Računi i blagajne',
    'accounts_empty': 'Nema evidentiranih računa.',
    'account_new': 'Novi račun',
    'account_edit': 'Uredi račun',
    'account_code': 'Šifra računa',
    'account_name': 'Naziv',
    'account_type': 'Vrsta računa',
    'currency': 'Valuta',
    'finance_operating_currency_only': 'Dozvoljene valute su samo EUR i BAM.',
    'forecast_currency_exclusions_title':
        'Neke stavke nisu uključene u prognozu (valuta nije EUR ni BAM)',
    'forecast_currency_exclusion_line': '{label} · {currency}',
    'opening_balance': 'Početno stanje',
    'current_balance': 'Trenutno stanje',
    'bank_name': 'Banka',
    'iban': 'IBAN',
    'plant_key': 'Pogon',
    'active': 'Aktivan',
    'inactive': 'Neaktivan',
    'deactivate_account': 'Deaktiviraj račun',
    'deactivate_account_confirm':
        'Račun više neće biti dostupan za nove transakcije. Nastaviti?',
    'save': 'Spremi',
    'cancel': 'Odustani',
    'refresh': 'Osvježi',
    'categories_title': 'Cash Flow kategorije',
    'categories_empty': 'Nema kategorija.',
    'category_new': 'Nova kategorija',
    'category_edit': 'Uredi kategoriju',
    'category_code': 'Šifra kategorije',
    'category_name': 'Naziv kategorije',
    'activity_type': 'Vrsta aktivnosti',
    'activity_operating': 'Operativna aktivnost',
    'activity_investing': 'Investiciona aktivnost',
    'activity_financing': 'Finansijska aktivnost',
    'sort_order': 'Redoslijed',
    'deactivate_category': 'Deaktiviraj kategoriju',
    'deactivate_category_confirm': 'Kategorija više neće biti dostupna za nove unose. Nastaviti?',
    'filter_active_only': 'Samo aktivne',
    'type_transactional': 'Transakcijski račun',
    'type_foreign_currency': 'Devizni račun',
    'type_cash_register': 'Blagajna',
    'type_virtual': 'Virtualni račun',
    'type_credit_line': 'Kreditni račun',
    'error_generic': 'Došlo je do greške. Pokušajte ponovo.',
    'error_function_not_found':
        'Servis za bankovne stavke nije dostupan (Cloud Function nije deployana). '
        'Osvježite aplikaciju kasnije ili kontaktirajte administratora.',
    'error_parse': 'Neispravan odgovor servera pri učitavanju podataka.',
    'error_server_internal':
        'Greška na serveru pri učitavanju podataka. Pokušajte ponovo za nekoliko sekundi.',
    'error_missing_company':
        'Nedostaje kontekst kompanije. Odjavite se i ponovo se prijavite.',
    'saved': 'Spremljeno.',
    'deactivated': 'Deaktivirano.',
    'pick_date': 'Odaberi datum',
    'card_transactions_title': 'Transakcije',
    'card_transactions_subtitle':
        'Nacrti, knjiženje, usklađivanje i storno operativnih novčanih tokova.',
    'card_realized_title': 'Realizovani Cash Flow',
    'card_realized_subtitle':
        'Sažetak knjiženih i usklađenih transakcija za odabrani period.',
    'transactions_title': 'Transakcije',
    'transactions_empty': 'Nema transakcija za odabrane filtere.',
    'transaction_new': 'Nova transakcija',
    'transaction_edit': 'Uredi nacrt',
    'transaction_detail': 'Detalji transakcije',
    'transaction_code': 'Šifra transakcije',
    'transaction_date': 'Datum transakcije',
    'value_date': 'Datum valute',
    'amount': 'Iznos',
    'direction': 'Smjer',
    'direction_inflow': 'Priliv',
    'direction_outflow': 'Odliv',
    'status': 'Status',
    'tx_status_draft': 'Nacrt',
    'tx_status_planned': 'Planirano',
    'tx_status_posted': 'Knjiženo',
    'tx_status_reconciled': 'Usklađeno',
    'tx_status_cancelled': 'Otkazano',
    'description': 'Opis',
    'reference': 'Referenca',
    'filter_status': 'Status',
    'filter_account': 'Račun',
    'filter_direction': 'Smjer',
    'filter_period': 'Period',
    'filter_all': 'Svi',
    'filter_all_accounts': 'Svi računi',
    'date_from': 'Datum od',
    'date_to': 'Datum do',
    'account': 'Račun',
    'category': 'Kategorija',
    'post_transaction': 'Knjiži',
    'post_transaction_confirm':
        'Knjiženje mijenja saldo računa. Nastaviti?',
    'reconcile_transaction': 'Uskladi',
    'reconcile_transaction_confirm':
        'Usklađivanje ne mijenja saldo računa. Nastaviti?',
    'reverse_transaction': 'Storniraj',
    'reverse_transaction_confirm':
        'Storno kreira novu transakciju suprotnog smjera. Original ostaje u historiji. Nastaviti?',
    'cancel_draft': 'Otkaži nacrt',
    'cancel_draft_confirm': 'Nacrt će biti otkazan bez promjene salda. Nastaviti?',
    'posted': 'Knjiženo.',
    'reconciled': 'Usklađeno.',
    'reversed': 'Storno izvršen.',
    'draft_cancelled': 'Nacrt otkazan.',
    'audit_section': 'Revizija',
    'audit_created_by': 'Kreirao',
    'audit_posted_by': 'Knjižio',
    'audit_reconciled_by': 'Uskladio',
    'audit_posted_at': 'Knjiženo',
    'audit_reconciled_at': 'Usklađeno',
    'link_reversal': 'Storno transakcija',
    'link_original': 'Originalna transakcija',
    'realized_title': 'Realizovani Cash Flow',
    'realized_period': 'Period',
    'realized_total_inflows': 'Ukupni prilivi',
    'realized_total_outflows': 'Ukupni odlivi',
    'realized_net_cash_flow': 'Neto novčani tok',
    'realized_closing_balance': 'Završno stanje',
    'realized_transaction_count': 'Broj transakcija',
    'realized_by_activity': 'Po vrsti aktivnosti',
    'realized_inflows': 'Prilivi',
    'realized_outflows': 'Odlivi',
    'realized_net': 'Neto',
    'load_report': 'Učitaj izvještaj',
    'select_account': 'Odaberi račun',
    'select_category': 'Odaberi kategoriju',
    'select_direction': 'Odaberi smjer',
    'invoices_hub_subtitle':
        'Fakture, potraživanja i obaveze — Callable sloj (P2).',
    'card_sales_invoices_title': 'Izlazne fakture',
    'card_sales_invoices_subtitle':
        'Nacrti, izdavanje i pregled potraživanja po fakturi.',
    'card_purchase_invoices_title': 'Ulazne fakture',
    'card_purchase_invoices_subtitle':
        'Nacrti, odobravanje i pregled obaveza po fakturi.',
    'card_receivables_title': 'Potraživanja',
    'card_receivables_subtitle':
        'Otvorene i djelimično plaćene izlazne fakture.',
    'card_payables_title': 'Obaveze',
    'card_payables_subtitle':
        'Otvorene i djelimično plaćene ulazne fakture.',
    'sales_invoices_title': 'Izlazne fakture',
    'sales_invoices_empty': 'Nema izlaznih faktura.',
    'sales_invoice_new': 'Nova izlazna faktura',
    'sales_invoice_edit': 'Uredi nacrt izlazne fakture',
    'purchase_invoices_title': 'Ulazne fakture',
    'purchase_invoices_empty': 'Nema ulaznih faktura.',
    'purchase_invoice_new': 'Nova ulazna faktura',
    'purchase_invoice_edit': 'Uredi nacrt ulazne fakture',
    'receivables_title': 'Potraživanja',
    'receivables_empty': 'Nema otvorenih potraživanja.',
    'receivables_open_list': 'Otvorene i djelimično plaćene fakture',
    'payables_title': 'Obaveze',
    'payables_empty': 'Nema otvorenih obaveza.',
    'payables_open_list': 'Otvorene i djelimično plaćene obaveze',
    'customer_id': 'Šifra kupca',
    'customer_name': 'Kupac',
    'supplier_id': 'Šifra dobavljača',
    'supplier_name': 'Dobavljač',
    'net_amount': 'Neto iznos',
    'tax_amount': 'PDV iznos',
    'total_amount': 'Ukupan iznos',
    'paid_amount': 'Plaćeno',
    'open_amount': 'Otvoreno',
    'issue_date': 'Datum izdavanja',
    'due_date': 'Datum dospijeća',
    'issue_sales_invoice': 'Izdaj fakturu',
    'approve_purchase_invoice': 'Odobri fakturu',
    'cancel_invoice': 'Otkaži fakturu',
    'cancel_invoice_confirm':
        'Faktura će biti otkazana prema pravilima backend lifecycle-a. Nastaviti?',
    'invoice_issued': 'Faktura je izdana.',
    'invoice_approved': 'Faktura je odobrena.',
    'invoice_cancelled': 'Faktura je otkazana.',
    'invoice_overdue': 'Dospjelo',
    'invoice_erp_synced': 'ERP',
    'invoice_erp_readonly_hint':
        'ERP-sinhronizovana faktura: ERP polja nisu ručno promjenjiva.',
    'open_items_count': 'Broj otvorenih faktura',
    'open_items_total': 'Ukupan otvoreni iznos',
    'open_items_overdue_count': 'Broj dospjelih faktura',
    'open_items_overdue_amount': 'Dospjeli iznos',
    'inv_status_draft': 'Nacrt',
    'inv_status_open': 'Otvoreno',
    'inv_status_partial': 'Djelimično plaćeno',
    'inv_status_paid': 'Plaćeno',
    'inv_status_cancelled': 'Otkazano',
    'allocate_to_invoices': 'Alociraj na fakture',
    'allocated_amount': 'Alocirano',
    'unallocated_amount': 'Nealocirano',
    'payment_allocations_section': 'Alokacije plaćanja',
    'allocations_empty': 'Nema alokacija.',
    'allocations_active_total': 'Ukupno aktivno alocirano',
    'allocation_add_invoice': 'Dodaj fakturu',
    'allocation_lines_empty': 'Dodajte jednu ili više faktura za alokaciju.',
    'allocation_line_amount': 'Iznos alokacije',
    'allocation_invoice_remaining': 'Preostali otvoreni iznos fakture',
    'allocation_batch_total': 'Zbir alokacija',
    'allocation_remaining_tx': 'Preostali nealocirani iznos transakcije',
    'allocation_confirm': 'Potvrdi alokaciju',
    'allocation_saved': 'Alokacija je spremljena.',
    'allocation_no_invoices': 'Nema odgovarajućih otvorenih faktura.',
    'allocation_pick_sales_invoice': 'Odaberi izlaznu fakturu',
    'allocation_pick_purchase_invoice': 'Odaberi ulaznu fakturu',
    'allocation_exceeds_unallocated': 'Zbir alokacija premašuje raspoloživi iznos transakcije.',
    'allocation_amount_required': 'Unesite iznos alokacije.',
    'allocation_amount_decimals': 'Najviše dvije decimale.',
    'allocation_amount_invalid': 'Iznos mora biti pozitivan.',
    'allocation_cancel': 'Poništi alokaciju',
    'allocation_cancel_confirm': 'Poništi',
    'allocation_cancel_warning':
        'Saldo računa se neće promijeniti. Faktura će ponovo dobiti otvoreni iznos. Originalna Cash Flow transakcija ostaje knjižena. Alokacija ostaje u historiji kao poništena.',
    'allocation_cancel_reason': 'Razlog poništenja',
    'allocation_cancelled': 'Alokacija je poništena.',
    'allocation_status_active': 'Aktivna',
    'allocation_status_cancelled': 'Poništena',
    'allocation_allocated_by': 'Alocirao',
    'allocation_allocated_at': 'Datum alokacije',
    'allocation_cancelled_at': 'Datum poništenja',
    'allocation_cancelled_by': 'Poništio',
    'invoice_number': 'Broj fakture',
    'card_planned_items_title': 'Planirane stavke',
    'card_planned_items_subtitle':
        'Planirani prilivi i odlivi s vjerovatnoćom i lifecycle odobrenja.',
    'card_forecast_title': 'Cash Flow prognoza',
    'card_forecast_subtitle':
        'Deterministička prognoza novčanog toka po bucketima (Callable sloj).',
    'card_advanced_cash_flow_title': 'Napredna Cash Flow analiza',
    'card_advanced_cash_flow_subtitle':
        'Scenariji likvidnosti na zaključanoj P3 prognozi — preset i Šta-ako.',
    'advanced_cash_flow_title': 'Napredna Cash Flow analiza',
    'scenario_new': 'Novi scenario',
    'scenario_edit': 'Uredi scenario',
    'scenario_detail': 'Detalj scenarija',
    'scenario_name': 'Naziv scenarija',
    'scenario_name_required': 'Naziv scenarija je obavezan.',
    'scenario_description': 'Opis',
    'scenario_type': 'Tip scenarija',
    'scenario_plant_or_all': 'Pogon (prazno = svi pogoni)',
    'scenario_filter_type': 'Tip scenarija',
    'scenario_filter_status': 'Status',
    'scenario_list_empty': 'Nema scenarija za odabrane filtere.',
    'scenario_list_closing': 'Završno stanje: {amount}',
    'scenario_list_minimum': 'Najniže stanje: {amount}',
    'scenario_list_meta': 'Verzija {version} · {updated} · {user}',
    'scenario_liquidity_warning': 'Upozorenje: prag minimalne likvidnosti',
    'scenario_revision': 'Verzija {n}',
    'scenario_not_found': 'Scenario nije pronađen.',
    'scenario_period_required': 'Period od–do je obavezan.',
    'scenario_preset_hint':
        'Pretpostavke za ovaj tip scenarija dolaze iz sistemskog preseta na backendu.',
    'scenario_what_if_fields': 'Šta-ako pretpostavke',
    'scenario_type_optimistic': 'Optimistični',
    'scenario_type_base': 'Osnovni',
    'scenario_type_pessimistic': 'Pesimistični',
    'scenario_type_what_if': 'Šta-ako',
    'scenario_status_draft': 'Nacrt',
    'scenario_status_calculated': 'Izračunato',
    'scenario_status_approved': 'Odobreno',
    'scenario_status_archived': 'Arhivirano',
    'scenario_section_base': 'Osnova',
    'scenario_section_assumptions': 'Pretpostavke',
    'scenario_section_result': 'Rezultat',
    'scenario_base_period': 'Period prognoze',
    'scenario_actual_inflows': 'Stvarni prilivi',
    'scenario_actual_outflows': 'Stvarni odlivi',
    'scenario_planned_inflows': 'Planirani prilivi',
    'scenario_planned_outflows': 'Planirani odlivi',
    'scenario_currencies_used': 'Korištene valute (početno stanje računa)',
    'scenario_assumption_preset': 'Sistemski preset',
    'scenario_assumption_user': 'Korisnik',
    'scenario_assumption_empty': '—',
    'scenario_assumption_value': 'Vrijednost',
    'scenario_unit_days': 'dana',
    'scenario_unit_percent': '%',
    'scenario_unit_currency': 'valuta',
    'scenario_result_closing': 'Projektovano završno stanje',
    'scenario_result_minimum': 'Najniže stanje u periodu',
    'scenario_result_minimum_date': 'Datum najnižeg stanja',
    'scenario_result_periods_below': 'Periodi ispod praga likvidnosti',
    'scenario_result_inflows': 'Ukupni projektovani prilivi',
    'scenario_result_outflows': 'Ukupni projektovani odlivi',
    'scenario_result_by_currency': 'Stanje po valuti (izvor backend)',
    'scenario_comparison_title': 'Poređenje scenarija',
    'scenario_comparison_metric': 'Pokazatelj',
    'scenario_comparison_open': 'Puni prikaz poređenja',
    'scenario_action_edit': 'Uredi',
    'scenario_action_calculate': 'Izračunaj',
    'scenario_action_recalculate': 'Ponovo izračunaj',
    'scenario_action_approve': 'Odobri',
    'scenario_action_archive': 'Arhiviraj',
    'scenario_action_new_version': 'Kreiraj novu verziju',
    'scenario_action_ok': 'Akcija je uspješno izvršena.',
    'scenario_assumption_receivableDelayDays_title': 'Kašnjenje naplate potraživanja',
    'scenario_assumption_receivableDelayDays_body':
        'Pozitivno = kasnija naplata u projekciji; negativno = ranija naplata. Ne mijenja knjižene transakcije.',
    'scenario_assumption_payableDelayDays_title': 'Kašnjenje plaćanja obaveza',
    'scenario_assumption_payableDelayDays_body':
        'Pozitivno = kasnija isplata; negativno = ranija isplata u projekciji planiranih odliva.',
    'scenario_assumption_receivableProbabilityAdjustment_title':
        'Promjena vjerovatnoće naplate',
    'scenario_assumption_receivableProbabilityAdjustment_body':
        'Korekcija ponderisanog priliva unutar dozvoljenog postotnog raspona.',
    'scenario_assumption_payableProbabilityAdjustment_title':
        'Promjena vjerovatnoće plaćanja',
    'scenario_assumption_payableProbabilityAdjustment_body':
        'Korekcija ponderisanog odliva unutar dozvoljenog postotnog raspona.',
    'scenario_assumption_plannedInflowAdjustmentPercent_title':
        'Povećanje ili smanjenje planiranih priliva',
    'scenario_assumption_plannedInflowAdjustmentPercent_body':
        'Postotna promjena nominalnih planiranih priliva; ne dira stvarne prilive.',
    'scenario_assumption_plannedOutflowAdjustmentPercent_title':
        'Povećanje ili smanjenje planiranih odliva',
    'scenario_assumption_plannedOutflowAdjustmentPercent_body':
        'Postotna promjena nominalnih planiranih odliva; ne smanjuje knjižene odlive.',
    'scenario_assumption_minimumLiquidityThreshold_title': 'Minimalni prag likvidnosti',
    'scenario_assumption_minimumLiquidityThreshold_body':
        'Opcionalni override company minimumCashReserve za ovaj scenarij.',
    'help_card_advanced_cash_flow_title': 'Napredna Cash Flow analiza',
    'help_card_advanced_cash_flow_body':
        'Deterministički scenariji na zaključanoj P3 prognozi: osnovni, optimistični, pesimistični i Šta-ako. Odobreni scenarij se ne mijenja tiho — nova verzija kreira nacrt.',
    'help_advanced_cash_flow_tab_title': 'Napredna Cash Flow analiza',
    'bawc_title': 'Budžet naspram realizacije i obrtni kapital',
    'help_card_bawc_title': 'Budžet naspram realizacije i obrtni kapital',
    'help_card_bawc_body':
        'Pregled planiranog i realizovanog novčanog toka te DSO/DPO pokazatelja za odabrani period — iz backend snapshot-a.',
    'bawc_filter_plant': 'Pogon',
    'bawc_currency': 'Valuta',
    'bawc_section_budget': 'Budžet naspram realizacije',
    'bawc_section_working_capital': 'Obrtni kapital',
    'bawc_planned': 'Plan',
    'bawc_actual': 'Realizacija',
    'bawc_variance_amount': 'Odstupanje (iznos)',
    'bawc_variance_percent': 'Odstupanje (%)',
    'bawc_variance_not_applicable': 'Nije primjenjivo',
    'bawc_metric_unavailable': 'Nije dostupno',
    'bawc_inflow': 'Priliv',
    'bawc_outflow': 'Odliv',
    'bawc_net_cash_flow': 'Neto Cash Flow',
    'bawc_planned_inflow': 'Planirani priliv',
    'bawc_actual_inflow': 'Realizovani priliv',
    'bawc_planned_outflow': 'Planirani odliv',
    'bawc_actual_outflow': 'Realizovani odliv',
    'bawc_planned_net': 'Planirani neto',
    'bawc_actual_net': 'Realizovani neto',
    'bawc_dso_period_end': 'DSO na kraju perioda',
    'bawc_dso_period_end_hint':
        'Periodični DSO: odnos otvorenih potraživanja i kreditnih prodaja u periodu, skaliran na broj dana.',
    'bawc_dso_collection_avg': 'Prosječni dani naplate',
    'bawc_dso_collection_avg_hint':
        'Prosjek stvarnih dana od izdavanja do potvrđene naplate za u potpunosti plaćene fakture u periodu.',
    'bawc_dpo_period_end': 'DPO na kraju perioda',
    'bawc_dpo_period_end_hint':
        'Periodični DPO: odnos otvorenih obaveza i debitnih nabavki u periodu, skaliran na broj dana.',
    'bawc_dpo_payment_avg': 'Prosječni dani plaćanja',
    'bawc_dpo_payment_avg_hint':
        'Prosjek stvarnih dana od odobrenja do potvrđenog plaćanja za u potpunosti plaćene ulazne fakture u periodu.',
    'bawc_dio': 'DIO',
    'bawc_ccc': 'CCC',
    'bawc_dio_ccc_unavailable':
        'Nije dostupno — nedostaju kanonski podaci o zalihama',
    'bawc_dio_unavailable_cogs':
        'Nije dostupno — nedostaje kanonski trošak prodane robe',
    'bawc_ccc_unavailable_dso':
        'Nije dostupno — nedostaje DSO na kraju perioda',
    'bawc_ccc_unavailable_dpo':
        'Nije dostupno — nedostaje DPO na kraju perioda',
    'bawc_breakdown_title': 'Raspodjela',
    'bawc_breakdown_period': 'Po periodu',
    'bawc_breakdown_category': 'Po kategoriji',
    'bawc_breakdown_plant': 'Po pogonu',
    'bawc_period': 'Period',
    'bawc_category': 'Kategorija',
    'bawc_plant': 'Pogon',
    'bawc_uncategorized': 'Nekategorizirano',
    'bawc_coverage_title': 'Pokrivenost podataka',
    'bawc_coverage_compact': '{count} upozorenja o dostupnosti podataka',
    'bawc_warn_no_budget': 'Nema odobrenog budžeta za odabrani period.',
    'bawc_warn_no_collection_payments':
        'Nema potvrđenih plaćanja za prosjek dana naplate.',
    'bawc_warn_no_payment_payments':
        'Nema potvrđenih plaćanja za prosjek dana plaćanja.',
    'bawc_warn_dio_ccc_unavailable':
        'DIO i CCC nisu dostupni jer podaci o zalihama još nisu povezani.',
    'bawc_warn_dio_unavailable_inventory':
        'DIO nije dostupan jer nedostaju kanonski podaci o zalihama.',
    'bawc_warn_dio_unavailable_cogs':
        'DIO nije dostupan jer nedostaje kanonski trošak prodane robe.',
    'bawc_warn_ccc_unavailable':
        'CCC nije dostupan jer nedostaju DSO ili DPO na kraju perioda.',
    'bawc_warn_inventory_erp_preferred':
        'Za zalihe se koristi ERP izvor jer ima prednost nad WMS.',
    'bawc_warn_cogs_erp_preferred':
        'Za trošak prodane robe koristi se ERP izvor jer ima prednost nad WMS.',
    'bawc_warn_budget_incomplete':
        'Neki budžetski redovi nisu uključeni jer nedostaje period ili smjer novca.',
    'bawc_empty_hint': 'Odaberite period i valutu, zatim pritisnite Osvježi.',
    'bawc_empty_period': 'Nema podataka za odabrani period i filtere.',
    'planned_items_title': 'Planirane stavke',
    'planned_items_empty': 'Nema planiranih stavki za odabrane filtere.',
    'planned_item_new': 'Nova planirana stavka',
    'planned_item_edit': 'Uredi nacrt planirane stavke',
    'planned_item_detail': 'Detalji planirane stavke',
    'planned_status_draft': 'Nacrt',
    'planned_status_approved': 'Odobreno',
    'planned_status_cancelled': 'Otkazano',
    'expected_date': 'Očekivani datum',
    'nominal_amount': 'Nominalni iznos',
    'weighted_amount': 'Ponderisani iznos',
    'probability_percent': 'Vjerovatnoća (%)',
    'probability_source': 'Izvor vjerovatnoće',
    'prob_source_manual_confirmed': 'Ručno potvrđeno',
    'prob_source_company_rule': 'Pravilo kompanije',
    'prob_source_system_default': 'Sistemski zadano',
    'approve_planned_item': 'Odobri stavku',
    'approve_planned_item_confirm':
        'Odobrena stavka ulazi u prognozu. Nakon odobrenja izmjena kanonskih polja nije dozvoljena. Nastaviti?',
    'cancel_planned_item': 'Otkaži stavku',
    'cancel_planned_item_confirm':
        'Stavka više neće ulaziti u prognozu. Nastaviti?',
    'planned_item_approved': 'Planirana stavka je odobrena.',
    'planned_item_cancelled': 'Planirana stavka je otkazana.',
    'planned_readonly_hint':
        'Odobrena stavka je read-only. Korekcija: otkaz + nova stavka.',
    'forecast_title': 'Cash Flow prognoza',
    'forecast_horizon': 'Horizont (dana)',
    'forecast_custom_period': 'Prilagođeni period',
    'forecast_use_horizon': 'Preset horizont',
    'forecast_use_custom': 'Prilagođeni period',
    'forecast_bucket_type': 'Vrsta bucketa',
    'forecast_bucket_day': 'Dan',
    'forecast_bucket_week': 'Sedmica',
    'forecast_bucket_month': 'Mjesec',
    'forecast_opening_balance': 'Početno stanje',
    'forecast_actual_inflows': 'Stvarni prilivi',
    'forecast_actual_outflows': 'Stvarni odlivi',
    'forecast_planned_nominal_inflows': 'Planirani nominalni prilivi',
    'forecast_planned_nominal_outflows': 'Planirani nominalni odlivi',
    'forecast_planned_weighted_inflows': 'Planirani ponderisani prilivi',
    'forecast_planned_weighted_outflows': 'Planirani ponderisani odlivi',
    'forecast_nominal_closing': 'Nominalni završni saldo',
    'forecast_weighted_closing': 'Ponderisani završni saldo',
    'forecast_buckets_empty': 'Nema bucket-a za odabrane parametre.',
    'forecast_minimum_cash_reserve': 'Minimalna gotovinska rezerva',
    'forecast_first_below_reserve_nominal': 'Prvi nominalni pad ispod rezerve',
    'forecast_first_below_reserve_weighted': 'Prvi ponderisani pad ispod rezerve',
    'forecast_min_nominal_balance': 'Minimalni nominalni saldo',
    'forecast_min_nominal_balance_date': 'Datum minimalnog nominalnog salda',
    'forecast_min_weighted_balance': 'Minimalni ponderisani saldo',
    'forecast_min_weighted_balance_date': 'Datum minimalnog ponderisanog salda',
    'forecast_negative_nominal_expected': 'Očekivan negativan nominalni saldo',
    'forecast_negative_weighted_expected': 'Očekivan negativan ponderisani saldo',
    'forecast_yes': 'Da',
    'forecast_no': 'Ne',
    'forecast_load': 'Učitaj prognozu',
    'forecast_period_label': 'Period prognoze',
    'advisory_section_title': 'Proaktivni finansijski nadzor',
    'advisory_controlling_section_title': 'Kontroling AI analiza',
    'advisory_empty': 'Nema upozorenja za odabrane filtere.',
    'advisory_load_error': 'Učitavanje upozorenja nije uspjelo.',
    'advisory_alert_not_found':
        'Upozorenje više nije dostupno. Možda je riješeno ili uklonjeno iz sustava.',
    'advisory_filter_status': 'Status',
    'advisory_filter_severity': 'Ozbiljnost',
    'advisory_filter_plant': 'Pogon',
    'advisory_filter_active': 'Aktivna upozorenja',
    'advisory_filter_history': 'Historija',
    'advisory_filter_all_plants': 'Svi pogoni',
    'advisory_filter_all_severities': 'Sve razine',
    'advisory_run_analysis': 'Analiziraj sada',
    'advisory_run_analysis_running': 'Analiza u tijeku…',
    'advisory_run_summary':
        'Evaluirano pravila: {rules} · nova: {created} · ažurirana: {updated} · riješena: {resolved} · preskočeno: {skipped}',
    'advisory_confidence_label': 'Pouzdanost: {score}%',
    'advisory_confidence_score': 'Pouzdanost',
    'advisory_plant_scope': 'Pogon: {plant}',
    'advisory_detected_range': 'Prvo otkriveno: {first} · zadnje: {last}',
    'advisory_severity_info': 'Informacija',
    'advisory_severity_medium': 'Srednja',
    'advisory_severity_high': 'Visoka',
    'advisory_severity_critical': 'Kritična',
    'advisory_status_open': 'Otvoreno',
    'advisory_status_acknowledged': 'Pregledano',
    'advisory_status_resolved': 'Riješeno',
    'advisory_status_dismissed': 'Odbačeno',
    'advisory_detail_title': 'Detalj upozorenja',
    'advisory_section_observed': 'Šta je Operonix uočio?',
    'advisory_section_why': 'Zašto mi Operonix ovo prikazuje?',
    'advisory_section_assessment': 'Procjena',
    'advisory_section_recommendation': 'Preporučena naredna akcija',
    'advisory_confidence_origin': 'Izvor pouzdanosti',
    'advisory_confidence_factors': 'Faktori pouzdanosti',
    'advisory_analysis_date': 'Datum analize',
    'advisory_facts_empty': 'Nema dostupnih činjenica za ovo upozorenje.',
    'advisory_fact_as_of': 'Stanje na: {date}',
    'advisory_acknowledge': 'Potvrdi da je pregledano',
    'advisory_acknowledged': 'Upozorenje je označeno kao pregledano.',
    'advisory_dismiss': 'Odbaci upozorenje',
    'advisory_dismissed': 'Upozorenje je odbačeno.',
    'advisory_feedback': 'Pošalji feedback',
    'advisory_feedback_title': 'Feedback na upozorenje',
    'advisory_feedback_helpful': 'Tačno',
    'advisory_feedback_not_helpful': 'Djelimično tačno',
    'advisory_feedback_incorrect_facts': 'Netačno',
    'advisory_feedback_wrong_severity': 'Nije relevantno',
    'advisory_feedback_comment': 'Komentar (opcionalno)',
    'advisory_feedback_submit': 'Pošalji feedback',
    'advisory_feedback_sent': 'Feedback je zaprimljen.',
    'advisory_dismiss_title': 'Razlog odbacivanja',
    'advisory_dismiss_confirm': 'Odbaci upozorenje',
    'advisory_dismiss_other': 'Opišite razlog',
    'advisory_dismiss_reason_risk_resolved': 'Rizik je već riješen',
    'advisory_dismiss_reason_known_circumstance': 'Poznata poslovna okolnost',
    'advisory_dismiss_reason_incorrect_incomplete_data':
        'Netačni ili nepotpuni podaci',
    'advisory_dismiss_reason_not_relevant': 'Nije relevantno',
    'advisory_dismiss_reason_other': 'Drugi razlog',
    'advisory_open_recommendation': 'Otvori preporučeni ekran',
    'advisory_section_decision': 'Odluka o preporuci',
    'advisory_accept_recommendation': 'Prihvati preporuku',
    'advisory_reject_recommendation': 'Odbij preporuku',
    'advisory_decision_accepted': 'Preporuka je prihvaćena.',
    'advisory_decision_rejected': 'Preporuka je odbijena.',
    'advisory_reject_title': 'Razlog odbijanja preporuke',
    'advisory_reject_confirm': 'Odbij preporuku',
    'advisory_reject_other': 'Opišite razlog',
    'advisory_reject_reason_not_relevant': 'Nije relevantno',
    'advisory_reject_reason_already_resolved': 'Već riješeno',
    'advisory_reject_reason_incorrect_incomplete_data':
        'Netačni ili nepotpuni podaci',
    'advisory_reject_reason_other_business_decision': 'Druga poslovna odluka',
    'advisory_reject_reason_other': 'Drugi razlog',
    'advisory_section_outcome': 'Ishod preporuke',
    'advisory_outcome_empty': 'Ishod preporuke još nije dostupan.',
    'advisory_outcome_load_error': 'Učitavanje ishoda nije uspjelo.',
    'advisory_telemetry_error': 'Telemetry nije zabilježen. Pokušajte ponovo.',
    'advisory_outcome_status': 'Status ishoda',
    'advisory_outcome_observation_window': 'Period posmatranja',
    'advisory_outcome_next_evaluation': 'Sljedeća evaluacija',
    'advisory_outcome_attribution': 'Atribucija',
    'advisory_outcome_confirmation_method': 'Metoda potvrde',
    'advisory_outcome_confirmed_impact': 'Potvrđeni finansijski efekat',
    'advisory_outcome_evidence_title': 'Dokazni zapisi',
    'advisory_outcome_evidence_before': 'Početna vrijednost',
    'advisory_outcome_evidence_after': 'Završna vrijednost',
    'advisory_outcome_evidence_observed_at': 'Vrijeme posmatranja',
    'advisory_outcome_value_unavailable': 'Nije dostupno',
    'advisory_outcome_status_outcome_pending': 'Rezultat se još posmatra',
    'advisory_outcome_status_outcome_confirmed': 'Rezultat je potvrđen činjenicama',
    'advisory_outcome_status_outcome_not_confirmed':
        'Preporučeni rezultat nije potvrđen',
    'advisory_outcome_status_outcome_unknown': 'Nema dovoljno dokaza',
    'advisory_outcome_message_outcome_pending': 'Rezultat se još posmatra.',
    'advisory_outcome_message_outcome_confirmed':
        'Rezultat je potvrđen činjenicama iz poslovnih podataka.',
    'advisory_outcome_message_outcome_not_confirmed':
        'Preporučeni rezultat nije potvrđen u periodu posmatranja.',
    'advisory_outcome_message_outcome_unknown':
        'Nema dovoljno dokaza za potvrdu ili odbijanje ishoda.',
    'advisory_outcome_attribution_direct': 'Direktna',
    'advisory_outcome_attribution_contributing': 'Doprinos',
    'advisory_outcome_attribution_uncertain': 'Neizvjesna',
    'advisory_outcome_attribution_not_attributable': 'Nije atribuirajuća',
    'advisory_outcome_confirmation_overdue_amount_reduction':
        'Smanjenje dospjelih iznosa',
    'advisory_outcome_confirmation_invoice_payment_timing':
        'Vrijeme naplate / plaćanja fakture',
    'advisory_outcome_confirmation_forecast_risk_removed':
        'Uklonjen rizik u prognozi',
    'advisory_outcome_evidence_overdue_amount': 'Dospjeli iznos',
    'advisory_outcome_evidence_open_amount': 'Otvoreni iznos',
    'advisory_outcome_evidence_forecast_signal': 'Signal prognoze likvidnosti',
    'retry': 'Ponovi',
    'more_actions': 'Više akcija',
    'advisory_resolution_reason': 'Razlog rješenja',
    'advisory_dismiss_reason_label': 'Razlog odbacivanja',
    'advisory_origin_deterministic_only': 'Procjena iz poslovnih podataka',
    'advisory_origin_deterministic_with_ai_interpretation':
        'Procjena iz podataka s AI objašnjenjem',
    'advisory_origin_insufficient_facts': 'Nedovoljno podataka za pouzdanu procjenu',
    'advisory_snapshot_threshold': 'Operativni prag',
    'advisory_snapshot_minimum_cash_reserve': 'Minimalna gotovinska rezerva',
    'advisory_snapshot_base_currency': 'Osnovna valuta',
    'advisory_snapshot_first_nominal_below_reserve_date':
        'Prvi datum ispod rezerve (nominalno)',
    'advisory_snapshot_first_weighted_below_reserve_date':
        'Prvi datum ispod rezerve (ponderisano)',
    'advisory_snapshot_minimum_nominal_balance': 'Najniži nominalni saldo',
    'advisory_snapshot_minimum_weighted_balance': 'Najniži ponderisani saldo',
    'advisory_snapshot_nominal_negative_balance_expected':
        'Očekivan negativan saldo (nominalno)',
    'advisory_snapshot_weighted_negative_balance_expected':
        'Očekivan negativan saldo (ponderisano)',
    'advisory_snapshot_customer_name': 'Kupac',
    'advisory_snapshot_supplier_name': 'Dobavljač',
    'advisory_snapshot_direction': 'Smjer',
    'advisory_snapshot_allocated_amount': 'Raspodijeljeni iznos',
    'advisory_snapshot_unallocated_amount': 'Neraspodijeljeni iznos',
    'advisory_snapshot_nominal_amount': 'Nominalni iznos',
    'advisory_snapshot_status': 'Status',
    'advisory_factor_fact_completeness': 'Potpunost podataka',
    'advisory_factor_forecast_horizon_days': 'Horizont prognoze',
    'advisory_factor_signal_strength': 'Jačina signala',
    'advisory_factor_data_freshness': 'Svježina podataka',
    'advisory_factor_days_one': '1 dan',
    'advisory_factor_days_many': '{count} dana',
    'advisory_freshness_current': 'Aktualni podaci',
    'advisory_freshness_minutes': 'Prije {count} min',
    'advisory_freshness_hours': 'Prije {count} h',
    'advisory_rule_liquidity_below_minimum_reserve_nominal':
        'Likvidnost ispod minimalne rezerve (nominalno)',
    'advisory_rule_liquidity_below_minimum_reserve_weighted':
        'Likvidnost ispod minimalne rezerve (ponderisano)',
    'advisory_rule_liquidity_negative_balance_expected_nominal':
        'Očekivan negativan saldo (nominalno)',
    'advisory_rule_liquidity_negative_balance_expected_weighted':
        'Očekivan negativan saldo (ponderisano)',
    'advisory_rule_receivables_overdue_material':
        'Značajna dospjela potraživanja',
    'advisory_rule_payables_due_soon_cluster':
        'Skup obaveza uskoro dospijeva',
    'advisory_rule_cash_unallocated_surplus': 'Neraspodijeljen višak gotovine',
    'advisory_rule_planned_items_draft_backlog':
        'Zaostali nacrti planiranih stavki',
    'advisory_rule_accounts_low_balance_single': 'Nizak saldo računa',
    'advisory_fact_forecast_liquidity_threshold': 'Prag likvidnosti iz prognoze',
    'advisory_fact_sales_invoice_open': 'Otvorena izlazna faktura',
    'advisory_fact_purchase_invoice_open': 'Otvorena ulazna faktura',
    'advisory_fact_cash_transaction': 'Gotovinska transakcija',
    'advisory_fact_planned_cash_item': 'Planirana stavka',
    'advisory_fact_account_balance': 'Saldo računa',
    'kpi_section_title': 'Rezultati AI preporuka',
    'kpi_section_subtitle':
        'Mjerljivi ishodi Finance AI preporuka za odabrani period (read-only snapshot).',
    'kpi_period_from': 'Period od',
    'kpi_period_to': 'Period do',
    'kpi_scope_line': 'Opseg: {scope} · {from} – {to}',
    'kpi_load_error': 'Učitavanje KPI rezultata nije uspjelo.',
    'kpi_empty_period': 'Nema interakcija ni evaluiranih ishoda za odabrani period.',
    'kpi_insufficient_data': 'Nema dovoljno podataka',
    'kpi_section_engagement': 'Angažman',
    'kpi_shown_count': 'Prikazane preporuke',
    'kpi_viewed_count': 'Pregledane preporuke',
    'kpi_accepted_count': 'Prihvaćene preporuke',
    'kpi_rejected_count': 'Odbijene preporuke',
    'kpi_viewed_rate': 'Stopa pregleda',
    'kpi_acceptance_rate': 'Stopa prihvatanja',
    'kpi_viewed_label': 'pregledanih',
    'kpi_shown_label': 'prikazanih',
    'kpi_accepted_label': 'prihvaćenih',
    'kpi_decision_label': 'odluka (prihvaćeno + odbijeno)',
    'kpi_section_execution': 'Izvršenje preporuka',
    'kpi_action_started_count': 'Pokrenute akcije',
    'kpi_action_completed_count': 'Završene akcije',
    'kpi_action_start_rate': 'Stopa pokretanja akcije',
    'kpi_action_completion_rate': 'Stopa završetka akcije',
    'kpi_action_started_label': 'pokrenutih',
    'kpi_action_completed_label': 'završenih',
    'kpi_avg_time_to_action': 'Prosječno vrijeme do završene akcije',
    'kpi_avg_time_pairs': 'Na osnovu {count} parova shown → action_completed',
    'kpi_duration_hours_minutes': '{hours} h {minutes} min',
    'kpi_duration_minutes': '{minutes} min',
    'kpi_duration_under_minute': 'Manje od 1 min',
    'kpi_section_outcomes': 'Ishodi',
    'kpi_outcome_confirmed_count': 'Potvrđeni ishodi',
    'kpi_outcome_not_confirmed_count': 'Nepotvrđeni ishodi',
    'kpi_outcome_not_confirmed_hint': 'Preporučeni rezultat nije potvrđen u periodu posmatranja.',
    'kpi_outcome_unknown_count': 'Neutvrđeni ishodi',
    'kpi_outcome_unknown_hint': 'Nema dovoljno dokaza za potvrdu ili odbijanje ishoda.',
    'kpi_confirmed_outcome_rate': 'Stopa potvrđenih ishoda',
    'kpi_positive_confirmed_outcome_rate': 'Stopa pozitivnih potvrđenih ishoda',
    'kpi_outcome_unknown_rate': 'Stopa neutvrđenih ishoda',
    'kpi_outcome_confirmed_label': 'potvrđenih',
    'kpi_outcome_evaluated_label': 'evaluiranih',
    'kpi_positive_outcome_label': 'pozitivnih s finansijskim rezultatom',
    'kpi_financial_result_label': 's determinističkim finansijskim rezultatom',
    'kpi_positive_outcome_hint':
        'Potvrđen rezultat bez finansijskog efekta (null) ne ulazi u numerator.',
    'kpi_outcome_unknown_label': 'neutvrđenih',
    'kpi_section_rejection': 'Razlozi odbijanja',
    'kpi_rejection_empty': 'Nema odbijenih preporuka u periodu.',
    'kpi_section_attribution': 'Atribucija ishoda',
    'kpi_attribution_eligible_hint':
        'Direct i contributing ulaze u potvrđeni finansijski efekat AI preporuka.',
    'kpi_attribution_excluded_hint':
        'Uncertain i not attributable ne ulaze u potvrđeni finansijski efekat.',
    'kpi_attribution_impact_note':
        'Iznosi ispod uključuju samo direct/contributing atribuciju.',
    'kpi_confirmed_impact_title': 'Potvrđeni finansijski efekat AI preporuka',
    'kpi_confirmed_impact_subtitle':
        'Samo deterministički potvrđeni iznosi iz evaluacije ishoda.',
    'kpi_confirmed_impact_empty':
        'Nema potvrđenog finansijskog efekta za odabrani period i opseg.',
    'kpi_multi_currency_warning':
        'Postoji više valuta — iznosi nisu sabrani bez kanonske konverzije.',
    'kpi_base_currency_total': 'Ukupno u osnovnoj valuti ({currency})',
    'kpi_contract_info_title': 'KPI ugovor',
    'kpi_contract_version': 'Verzija ugovora',
    'kpi_evaluator_version': 'Verzija evaluatora',
    'kpi_contract_sources': 'Izvorne kolekcije:',
    'kpi_neutral_disclaimer':
        'Ovi KPI-jevi mjere učinak Finance AI preporuka, ne opšte finansijske rezultate kompanije.',
    'notification_section_title': 'In-app obavijesti',
    'notification_empty': 'Nema obavijesti za odabrane filtere.',
    'notification_load_error': 'Učitavanje obavijesti nije uspjelo.',
    'notification_filter_active': 'Aktivne',
    'notification_filter_history': 'Historija',
    'notification_filter_all': 'Sve',
    'notification_filter_unread': 'Nepročitane',
    'notification_scope_company_wide': 'Cijela kompanija',
    'notification_plant_scope': 'Pogon: {plant}',
    'notification_scope_label': 'Opseg',
    'notification_delivered_at': 'Dostavljeno: {time}',
    'notification_generation_revision': 'Generacija {gen} · revizija {rev}',
    'notification_detail_title': 'Detalj obavijesti',
    'notification_delivery_status': 'Status dostave',
    'notification_mark_read': 'Označi kao pročitano',
    'notification_marked_read': 'Obavijest je označena kao pročitana.',
    'notification_open_alert': 'Otvori povezano upozorenje',
    'notification_alert_unavailable':
        'Povezano upozorenje više nije u sustavu. Prikazani su podaci iz obavijesti.',
    'notification_closed_reason': 'Razlog zatvaranja',
    'notification_status_unread': 'Nepročitano',
    'notification_status_read': 'Pročitano',
    'notification_status_acknowledged': 'Potvrđeno',
    'notification_status_superseded': 'Zamijenjeno',
    'notification_status_closed': 'Zatvoreno',
    'card_bank_statements_title': 'Bankovne stavke',
    'card_bank_statements_subtitle':
        'Import iz ERP-a, pregled stavki, prijedlozi uparivanja i potvrda usklađivanja.',
    'bank_statements_title': 'Bankovne stavke',
    'bank_statements_empty': 'Nema bankovnih stavki za odabrane filtere.',
    'bank_import': 'Pokreni import',
    'bank_import_title': 'Import bankovnih stavki',
    'bank_import_connection': 'ERP veza',
    'bank_import_account': 'Bankovni račun',
    'bank_import_started': 'Import je pokrenut.',
    'bank_import_status': 'Status importa',
    'bank_import_success': 'Bankovne stavke su uspješno importovane.',
    'bank_import_success_detail':
        'Import završen: {created} novih, {updated} ažuriranih stavki.',
    'bank_import_partial':
        'Import djelomično uspješan ({failed} grešaka). Provjerite sync log.',
    'bank_import_failed': 'Import bankovnih stavki nije uspio.',
    'bank_ignore': 'Ignoriši stavku',
    'bank_restore': 'Vrati ignorisanu stavku',
    'bank_ignore_reason': 'Razlog ignorisanja',
    'bank_detail_title': 'Bankovna stavka',
    'bank_booking_date': 'Datum knjiženja',
    'bank_value_date': 'Datum valute',
    'bank_counterparty': 'Partner / platitelj',
    'bank_reference': 'Referenca plaćanja',
    'bank_description': 'Opis',
    'bank_status_imported': 'Uvezeno',
    'bank_status_unmatched': 'Neupareno',
    'bank_status_suggested': 'Ima prijedloge',
    'bank_status_confirmed': 'Potvrđeno',
    'bank_status_posted': 'Knjiženo',
    'bank_status_partially_reconciled': 'Djelimično usklađeno',
    'bank_status_reconciled': 'Usklađeno',
    'bank_status_ignored': 'Ignorisano',
    'bank_match_suggestions_title': 'Prijedlozi uparivanja',
    'bank_match_suggestions_empty': 'Nema prijedloga za ovu stavku.',
    'bank_match_generate': 'Generiši prijedloge',
    'bank_match_generate_success': 'Generisano {count} prijedlog(a).',
    'bank_match_generate_none': 'Nema novih kandidata za uparivanje.',
    'bank_match_generate_skipped_reconciled':
        'Usklađena/knjižena stavka — novi prijedlozi se ne generišu.',
    'bank_match_suggestions_empty_reconciled':
        'Stavka je već usklađena — prijedlozi više nisu potrebni.',
    'bank_match_score': 'Score',
    'bank_match_confidence': 'Pouzdanost',
    'bank_match_open_amount': 'Otvoreni iznos fakture',
    'bank_match_signals': 'Poslovni razlozi',
    'bank_match_blocking': 'Blokirajući razlozi',
    'bank_match_dismiss': 'Odbaci prijedlog',
    'bank_match_restore_suggestion': 'Vrati odbačeni prijedlog',
    'bank_match_dismiss_reason': 'Razlog odbacivanja',
    'bank_match_continue_confirm': 'Nastavi na potvrdu',
    'bank_match_blocked_hint':
        'Prijedlog ima blokirajuće razloge i ne može se potvrditi.',
    'bank_match_confirm_title': 'Potvrda uparivanja',
    'bank_match_confirm_preview': 'Pregled prije potvrde',
    'bank_match_bank_amount': 'Bankovna stavka',
    'bank_match_allocated': 'Raspoređeno',
    'bank_match_unallocated': 'Neraspoređeno',
    'bank_match_result_partial': 'Rezultat: djelimično usklađeno',
    'bank_match_result_full': 'Rezultat: potpuno usklađeno',
    'bank_match_result_over': 'Raspodjela prelazi iznos stavke',
    'bank_match_category': 'Cash Flow kategorija',
    'bank_match_note': 'Napomena',
    'bank_match_add_line': 'Dodaj fakturu',
    'bank_match_confirm_submit': 'Potvrdi uparivanje',
    'bank_match_confirmations_title': 'Historija potvrda',
    'bank_match_confirmations_empty': 'Nema potvrda za ovu stavku.',
    'bank_match_confirmation_detail': 'Detalj potvrde',
    'bank_match_confirmation_unlabeled': 'Potvrda uparivanja',
    'bank_match_confirmed_by': 'Potvrdio',
    'bank_match_confirmed_at': 'Vrijeme potvrde',
    'bank_match_cash_transaction': 'Cash Flow transakcija',
    'bank_match_allocations': 'Alokacije po fakturama',
    'bank_match_cancel': 'Otkaži potvrdu',
    'bank_match_cancel_confirm_title': 'Otkazivanje potvrde uparivanja',
    'bank_match_cancel_confirm_body':
        'Operonix Industrial će kreirati reversal Cash Flow zapis, poništiti povezane alokacije, vratiti otvorene iznose faktura i zadržati puni audit trag. Nema brisanja podataka.',
    'bank_match_cancel_reason': 'Razlog otkazivanja',
    'bank_match_cancel_result_title': 'Rezultat otkazivanja',
    'bank_match_cancelled_at': 'Vrijeme otkazivanja',
    'bank_match_cancelled_by': 'Otkazao',
    'bank_match_reversal_txn': 'Reversal transakcija',
    'bank_match_cancelled': 'Potvrda je otkazana.',
    'bank_audit_trail_title': 'Historija i audit trag',
    'bank_audit_trail_empty': 'Nema audit zapisa za ovu bankovnu stavku.',
    'bank_audit_trail_tap_detail': 'Dodirnite za prije/poslije i povezane zapise',
    'audit_performed_by': 'Izvršio',
    'audit_entity_type': 'Tip entiteta',
    'audit_source': 'Izvor',
    'audit_request_id': 'Request ID',
    'audit_related_entities': 'Povezani zapisi',
    'audit_before': 'Stanje prije',
    'audit_after': 'Stanje poslije',
    'audit_action_bank_statement_import_create': 'Bankovna stavka uvezena',
    'audit_action_bank_statement_import_update': 'Bankovna stavka ažurirana iz ERP-a',
    'audit_action_bank_statement_ignore': 'Bankovna stavka ignorisana',
    'audit_action_bank_statement_restore': 'Bankovna stavka vraćena iz ignorisanih',
    'audit_action_bank_statement_status_suggested': 'Status stavke: prijedlozi dostupni',
    'audit_action_bank_match_suggestion_create': 'Prijedlog uparivanja generisan',
    'audit_action_bank_match_suggestion_refresh': 'Prijedlog uparivanja osvježen',
    'audit_action_bank_match_suggestion_dismiss': 'Prijedlog uparivanja odbačen',
    'audit_action_bank_match_suggestion_restore': 'Odbačeni prijedlog vraćen',
    'audit_action_bank_match_confirm': 'Potvrda uparivanja kreirana',
    'audit_action_bank_match_post': 'Bankovna stavka usklađena (knjiženje)',
    'audit_action_bank_match_allocate': 'Alokacija na fakturu kreirana',
    'audit_action_bank_match_cancel': 'Potvrda uparivanja otkazana',
    'audit_action_cancel': 'Alokacija poništena',
    'audit_source_manual': 'Ručna radnja korisnika',
    'audit_source_scheduled': 'Automatski posao (scheduler)',
    'audit_source_system': 'Sistem',
    'audit_entity_finance_bank_statement_transactions': 'Bankovna stavka',
    'audit_entity_finance_bank_match_confirmations': 'Potvrda uparivanja',
    'audit_entity_finance_bank_match_suggestions': 'Prijedlog uparivanja',
    'audit_entity_finance_payment_allocation': 'Alokacija plaćanja',
    'audit_entity_finance_cash_transactions': 'Cash Flow transakcija',
    'bank_match_confidence_high': 'Visoka pouzdanost',
    'bank_match_confidence_medium': 'Srednja pouzdanost',
    'bank_match_confidence_low': 'Niska pouzdanost',
    'bank_match_intro_primary':
        'Operonix Industrial je pronašao moguće fakture za ovu bankovnu stavku. '
        'Prvo pregledajte prijedloge s visokom pouzdanošću i provjerite razloge podudaranja prije potvrde.',
    'bank_match_show_weak': 'Prikaži slabe prijedloge ({count})',
    'bank_match_hide_weak': 'Sakrij slabe prijedloge',
    'bank_match_card_open': 'Otvoreno',
    'bank_match_card_title': 'Faktura {number} — {partner}',
    'bank_match_card_bank_payment': 'Bankovna uplata',
    'bank_match_card_bank_payout': 'Bankovna isplata',
    'bank_match_amount_diff_none': 'Iznosi se podudaraju',
    'bank_match_amount_diff_over': 'Banka je veća za {amount}',
    'bank_match_amount_diff_under': 'Banka je manja za {amount}',
    'bank_match_top_reasons': 'Razlozi',
    'bank_match_tap_for_detail': 'Dodirnite za detaljno poređenje',
    'bank_match_detail_title': 'Poređenje prijedloga',
    'bank_match_detail_bank_section': 'Bankovna stavka',
    'bank_match_detail_invoice_section': 'Faktura',
    'bank_match_detail_why': 'Zašto je predložena',
    'bank_match_detail_warnings': 'Upozorenja',
    'bank_match_detail_invoice_total': 'Ukupni iznos fakture',
    'bank_match_detail_invoice_due': 'Datum dospijeća',
    'bank_match_detail_partner_account': 'Račun partnera',
    'bank_match_detail_invoice_type_sales': 'Izlazna faktura (sales)',
    'bank_match_detail_invoice_type_purchase': 'Ulazna faktura (purchase)',
    'bank_match_detail_invoice_number': 'Broj fakture',
    'bank_match_detail_back': 'Nazad na druge prijedloge',
    'bank_match_detail_blocked_title': 'Potvrda nije moguća',
    'bank_match_dismissed_section': 'Odbačeni prijedlozi',
    'bank_match_hidden_useful_hint':
        'Još {count} korisnih prijedloga nije prikazano — prikažite slabe ili generišite ponovo.',
    'bank_match_sentence_invoice_number_exact':
        'Broj fakture pronađen je u pozivu na broj',
    'bank_match_sentence_payment_reference_exact':
        'Referenca plaćanja potpuno odgovara fakturi',
    'bank_match_sentence_exact_amount':
        'Iznos bankovne stavke potpuno odgovara otvorenom iznosu fakture',
    'bank_match_sentence_partial_amount':
        'Iznos bankovne stavke djelimično pokriva otvoreni iznos fakture',
    'bank_match_sentence_partner_account_exact':
        'Bankovni račun partnera se podudara',
    'bank_match_sentence_partner_name_normalized':
        'Naziv partnera se podudara',
    'bank_match_sentence_due_date_proximity':
        'Datum plaćanja je blizu datuma dospijeća',
    'bank_match_sentence_booking_date_proximity':
        'Datum knjiženja je blizu datuma dospijeća',
    'bank_match_sentence_currency_exact': 'Valuta se podudara',
    'bank_match_sentence_open_amount_compatible':
        'Otvoreni iznos fakture je kompatibilan s bankovnom stavkom',
    'bank_match_warn_low_score':
        'Niska pouzdanost — provjerite ručno prije potvrde',
    'bank_match_warn_amount_diff': 'Iznos se razlikuje od otvorenog iznosa fakture',
    'bank_match_warn_partner_weak':
        'Partner nije pouzdano prepoznat (samo naziv, bez računa ili iznosa)',
    'bank_match_warn_currency_date_only':
        'Podudara se uglavnom samo valuta i/ili blizina datuma',
    'bank_match_block_sentence_currency_mismatch': 'Valuta fakture i bankovne stavke se ne podudaraju',
    'bank_match_block_sentence_invoice_closed': 'Faktura je već zatvorena',
    'bank_match_block_sentence_invoice_conflict_requires_review':
        'Faktura ima sync konflikt koji zahtijeva pregled',
    'bank_match_block_sentence_bank_transaction_ignored':
        'Bankovna stavka je ignorisana',
    'bank_match_block_sentence_bank_transaction_already_posted':
        'Bankovna stavka je već knjižena ili usklađena',
    'bank_match_block_sentence_invalid_direction': 'Smjer fakture ne odgovara bankovnoj stavci',
    'bank_match_block_sentence_missing_open_amount': 'Faktura nema otvoreni iznos',
    'concurrency_refresh_hint':
        'Podaci su osvježeni ispod. Provjerite iznose i ponovo pritisnite Potvrdi uparivanje.',
    'bank_match_confirm_not_saved':
        'Uparivanje nije potvrđeno — ništa nije spremljeno.',
    'filter_currency': 'Valuta',
    'bank_signal_exact_amount': 'Tačan iznos',
    'bank_signal_partial_amount': 'Djelimičan iznos',
    'bank_signal_invoice_number_exact': 'Broj fakture',
    'bank_signal_payment_reference_exact': 'Referenca plaćanja',
    'bank_signal_partner_account_exact': 'Račun partnera',
    'bank_signal_partner_name_normalized': 'Naziv partnera',
    'bank_signal_due_date_proximity': 'Blizina dospijeća',
    'bank_signal_booking_date_proximity': 'Blizina datuma knjiženja',
    'bank_signal_currency_exact': 'Ista valuta',
    'bank_signal_open_amount_compatible': 'Kompatibilan otvoreni iznos',
    'bank_blocking_currency_mismatch': 'Valuta se ne podudara',
    'bank_blocking_invoice_closed': 'Faktura je zatvorena',
    'bank_blocking_invoice_conflict_requires_review': 'Faktura zahtijeva sync pregled',
    'bank_blocking_bank_transaction_ignored': 'Bankovna stavka je ignorisana',
    'bank_blocking_bank_transaction_already_posted': 'Bankovna stavka je već knjižena',
    'bank_blocking_invalid_direction': 'Neispravan smjer',
    'bank_blocking_missing_open_amount': 'Nema otvorenog iznosa',
    'bank_blocking_duplicate_candidate': 'Dupli kandidat',
    'help_info_tooltip': 'Pojašnjenje',
    'help_info_close': 'Zatvori',
    'help_term_open_amount_title': 'Otvoreni iznos',
    'help_term_open_amount_body':
        'Dio fakture koji još nije plaćen. Kad potvrdite uparivanje, ovaj iznos se smanjuje za uplaćeni dio.',
    'help_term_unallocated_title': 'Neraspoređeni iznos',
    'help_term_unallocated_body':
        'Dio bankovne stavke koji niste još povezali s fakturama. Ostaje neusmjeren dok ga ne alocirate pri potvrdi.',
    'help_term_partially_reconciled_title': 'Djelimično usklađeno',
    'help_term_partially_reconciled_body':
        'Bankovna stavka je djelimično povezana s fakturama — dio iznosa je raspoređen, dio još nije.',
    'help_term_match_confidence_title': 'Pouzdanost prijedloga',
    'help_term_match_confidence_body':
        'Koliko Operonix vjeruje da bankovna stavka odgovara toj fakturi, na temelju iznosa, partnera i reference. '
        'Visoka pouzdanost ne zamjenjuje vašu provjeru.',
    'help_term_cash_flow_category_title': 'Cash Flow kategorija',
    'help_term_cash_flow_category_body':
        'Razvrstava novac u operativni, investicioni ili finansijski tok — potrebna pri potvrdi uparivanja za izvještaj novca.',
    'help_cash_flow_tab_title': 'Tab Cash Flow — pregled',
    'help_cash_flow_tab_body':
        'Operativni novčani tok u Operonixu: evidentirate račune i blagajne, kategorije Cash Flow-a, '
        'ručne transakcije, planirane stavke i prognozu. Bankovne stavke iz ERP-a uparujete s fakturama '
        'i potvrđujete knjiženje. Sve mutacije idu preko sigurnog backend sloja; iznosi na fakturama '
        'ne računava aplikacija lokalno.\n\n'
        'Referent (accounting_clerk) uglavnom unosi nacrte i pregleda; šef računovodstva, admin i '
        'super_admin odobravaju, knjiže, usklađuju banku i otkazuju potvrde.',
    'help_card_accounts_title': 'Računi i blagajne',
    'help_card_accounts_body':
        'Šifrarnik novčanih mjesta: bankovni računi, devizni računi, blagajne. Ovdje vidite trenutno '
        'stanje koje backend održava na temelju knjiženih transakcija. Račun mora postojati prije '
        'knjiženja uplate/isplate ili bankovne potvrde.',
    'help_card_categories_title': 'Cash Flow kategorije',
    'help_card_categories_body':
        'Kategorije razvrstavaju svaki novčani tok u operativnu, investicionu ili finansijsku aktivnost '
        '(Cash Flow izvještaj). Obavezne su pri kreiranju transakcije ili potvrdi bankovne stavke.',
    'help_card_transactions_title': 'Transakcije',
    'help_card_transactions_body':
        'Ručni operativni novac: nacrt → knjiženje → usklađivanje ili storno. Za alokaciju na fakturu '
        'koristite akciju na knjiženoj transakciji. Ovo nije isto što i bankovna stavka iz ERP-a — '
        'banka ima poseban tok uvoza i potvrde uparivanja.',
    'help_card_realized_title': 'Realizovani Cash Flow',
    'help_card_realized_body':
        'Sažetak već knjiženih i usklađenih transakcija za odabrani period. Koristite za brzu sliku '
        'priliva i odliva po računu, kategoriji i smjeru — bez ručnog sabiranja u Excelu.',
    'help_card_planned_items_title': 'Planirane stavke',
    'help_card_planned_items_body':
        'Budući očekivani prilivi i odlivi (npr. planirane rate, poznate obaveze). Nacrt se odobrava '
        'prije nego uđe u prognozu. Ne zamjenjuje stvarne bankovne izvode.',
    'help_card_forecast_title': 'Prognoza Cash Flow-a',
    'help_card_forecast_body':
        'Projekcija novca na temelju planiranih stavki i poznatog stanja računa. Pomaže vidjeti '
        'mogući manjak likvidnosti u narednim tjednima — operativna procjena, ne ERP izvještaj.',
    'help_card_bank_statements_title': 'Bankovne stavke',
    'help_card_bank_statements_body':
        'Stavke s bankovnog izvoda uvezenog iz ERP veze. Tipičan tok:\n'
        '1) Pokreni import (ERP veza + bankovni račun).\n'
        '2) Pregledaj stavke i filtere (period, račun, status, smjer, valuta).\n'
        '3) Generiši prijedloge uparivanja — priliv traži izlazne (sales) fakture, odliv ulazne (purchase).\n'
        '4) Ručno potvrdi iznose po fakturi (djelimično ili potpuno).\n'
        '5) Pregledaj historiju potvrde; po potrebi otkaz (reversal, bez brisanja).\n\n'
        'Referent vidi sve; import, ignore i potvrdu rade manager/admin/super_admin.',
    'help_invoices_tab_title': 'Tab Fakture i otvorene stavke',
    'help_invoices_tab_body':
        'Operativne fakture i otvorena potraživanja/obaveze unutar tenanta. Izlazne i ulazne fakture '
        'mogu doći iz ERP sync-a ili ručnog nacrta. Otvoreni iznosi služe za alokacije plaćanja i '
        'bankovno uparivanje.',
    'help_card_sales_invoices_title': 'Izlazne fakture',
    'help_card_sales_invoices_body':
        'Fakture kupcima: nacrt, izdavanje, otkaz. Otvoreni iznos se smanjuje alokacijama i bankovnom '
        'potvrdom uplate. Status sync konflikta blokira automatske prijedloge dok se ne riješi u ERP-u.',
    'help_card_purchase_invoices_title': 'Ulazne fakture',
    'help_card_purchase_invoices_body':
        'Fakture dobavljača: nacrt, odobrenje, otkaz. Koriste se pri uparivanju odliva s bankovne stavke '
        'i ručnoj alokaciji plaćanja.',
    'help_card_receivables_title': 'Potraživanja',
    'help_card_receivables_body':
        'Pregled otvorenih izlaznih faktura po kupcu — dospijeća, zakašnjenja i ukupni otvoreni iznos '
        'za brzu kontrolu naplate.',
    'help_card_payables_title': 'Obaveze',
    'help_card_payables_body':
        'Pregled otvorenih ulaznih faktura prema dobavljačima — šta je za platiti i u kojem iznosu.',
    'help_erp_tab_title': 'Tab ERP integracija',
    'help_erp_tab_body':
        'Povezivanje Operonix Financija s vašim računovodstvenim sustavom (npr. Pantheon). Veza drži '
        'credentials na serveru; aplikacija ne piše direktno u ERP bankovni izvod. Sync poslovi povlače '
        'fakture i bankovne stavke; mapiranja usklađuju polja; logovi pomažu pri greškama.',
    'help_erp_connections_title': 'Aktivne ERP veze',
    'help_erp_connections_body':
        'Lista konfiguriranih konektora po kompaniji. Nova veza zahtijeva admin/manager ovlasti. '
        'Bez aktivne veze bankovni import i sync faktura ne rade.',
    'help_erp_bank_tile_title': 'Bankovne stavke (iz ERP taba)',
    'help_erp_bank_tile_body':
        'Isti ekran kao u tabu Cash Flow — brzi ulaz nakon podešavanja veze. Import bankovnog izvoda '
        'radi ovdje ili na listi stavki (ikona oblaka).',
    'help_erp_integration_dashboard_title': 'Pregled integracije',
    'help_erp_integration_dashboard_body':
        'Sažetak stanja konektora, zadnjih sync runova i osnovnih KPI integracije.',
    'help_erp_document_links_title': 'Veze dokumenata',
    'help_erp_document_links_body':
        'Mapiranje Operonix entiteta (nalog, faktura, …) na zapise u ERP-u radi traceability.',
    'help_erp_control_snapshots_title': 'Kontrolni snimci',
    'help_erp_control_snapshots_body':
        'Snimci za reconciliaciju kontroling podataka između Operonixa i ERP-a.',
    'help_erp_error_resolution_title': 'Rješavanje grešaka sinkronizacije',
    'help_erp_error_resolution_body':
        'Ponovni pokušaj ili otkaz sync poslova koji su pali; prvi korak kad import ne donese očekivane stavke.',
    'help_erp_sync_jobs_title': 'Sync poslovi',
    'help_erp_sync_jobs_body':
        'Pregled zakazanih i ručnih poslova sinkronizacije — status, trajanje, tip (fakture, banka, …).',
    'help_erp_sync_logs_title': 'Sync logovi',
    'help_erp_sync_logs_body':
        'Detaljni zapisi po poslu — korisno za support i audit kada treba vidjeti šta je ERP vratio.',
    'help_erp_mappings_title': 'Mapiranja',
    'help_erp_mappings_body':
        'Pravila kako ERP polja postaju Operonix finance_* dokumenti. Ne mijenjajte bez razumijevanja '
        'poslovnog uticaja na fakture i banku.',
    'help_erp_csv_export_title': 'CSV / Excel izvoz',
    'help_erp_csv_export_body':
        'Veze koje podržavaju izvoz podataka u CSV/Excel za ručnu provjeru ili vanjski alat.',
    'help_bank_list_title': 'Lista bankovnih stavki',
    'help_bank_list_body':
        'Prikaz uvezenih stavki s bankovnog izvoda. Filter perioda je na klijentu (datum knjiženja); '
        'ostali filteri su po statusu, računu, smjeru i valuti. Ikona oblaka: import (ERP veza + račun). '
        'Tap na stavku otvara detalj, prijedloge i historiju potvrda.',
    'help_bank_import_title': 'Import bankovnog izvoda',
    'help_bank_import_body':
        'Ručno pokretanje povlačenja novih stavki iz ERP-a za odabranu vezu i bankovni račun. '
        'Nakon importa osvježite listu. Status sync runa prikazuje se u dijalogu. Samo manager/admin/super_admin.',
    'help_bank_detail_title': 'Detalj bankovne stavke',
    'help_bank_detail_body':
        'Osnovni podaci stavke (iznos, smjer, partner, reference). Ignoriraj stavku samo dok '
        'nije knjižena ili usklađena (imported, unmatched, suggested, confirmed). '
        'Knjižene/usklađene stavke nije moguće ignorisati — za poništavanje uparivanja koristite '
        'otkazivanje potvrde u historiji. Generiši prijedloge nakon importa. '
        'Prijedlog s crvenim blocking razlozima ne može u potvrdu.',
    'help_bank_suggestions_title': 'Prijedlozi uparivanja',
    'help_bank_suggestions_body':
        'Automatski kandidati: faktura, score, pouzdanost i poslovni signali (iznos, referenca, …). '
        'Priliv → samo sales fakture; odliv → samo purchase. Odbaci loše prijedloge; odbačeni se '
        'ne vraćaju automatski osim restore akcije. Nastavi na potvrdu ne popunjava iznos — vi odlučujete.\n\n'
        'Prijedlog s blocking razlozima ne može u potvrdu — razlozi su navedeni na kartici prijedloga.',
    'help_bank_confirm_title': 'Potvrda uparivanja',
    'help_bank_confirm_body':
        'Ručno zadajete iznos po fakturi (1 ili više linija), Cash Flow kategoriju i napomenu. '
        'Pregled prije potvrde pokazuje bankovni iznos, raspoređeno i neraspoređeno. Djelimična uplata '
        'daje partially_reconciled; puna raspodjela reconciled. Isti requestId pri ponovnom slanju ne duplira.',
    'help_bank_confirmation_title': 'Historija potvrde',
    'help_bank_confirmation_body':
        'Audit zapis: ko je potvrdio, Cash Flow transakcija, alokacije po fakturama, status usklađivanja. '
        'Otkaz (manager+) kreira reversal transakciju i vraća otvorene iznose faktura — nema brisanja zapisa.',
    'help_bank_audit_trail_title': 'Historija i audit trag',
    'help_bank_audit_trail_body':
        'IATF trag svih poslovno relevantnih događaja za ovu bankovnu stavku — učitava se iz finance_audit_logs '
        'pri svakom otvaranju. Prikazuje tko, kada, šta je promijenjeno (prije/poslije), razlog i povezane entitete. '
        'Zapisi se ne brišu i ne mijenjaju nakon snimanja.',
    'finance_assistant_title': 'Finance asistent',
    'finance_assistant_module': 'Finance & Controlling',
    'finance_assistant_fab_title': 'Pitaj Finance asistenta',
    'finance_assistant_fab_subtitle':
        'Objašnjava ekran, pojmove i sljedeće korake u cijelom Finance modulu.',
    'finance_assistant_current_screen': 'Trenutno objašnjavam: {screen}',
    'finance_assistant_new_chat': 'Novi razgovor',
    'finance_assistant_input_hint': 'Postavite pitanje…',
    'finance_assistant_ask_more': 'Pitaj Finance asistenta više o ovome',
    'finance_assistant_ctx_status': 'Status stavke: {status}',
    'finance_assistant_ctx_actions': 'Dostupne akcije: {actions}',
    'finance_assistant_screen_bank_statements_list': 'Bankovne stavke',
    'finance_assistant_screen_bank_statement_detail': 'Detalj bankovne stavke',
    'finance_assistant_screen_bank_match_confirm': 'Potvrda uparivanja',
    'finance_assistant_screen_bank_match_confirmation_detail': 'Detalj potvrde',
    'finance_assistant_screen_bank_match_suggestion_detail': 'Detalj prijedloga uparivanja',
    'finance_assistant_context_changed':
        'Sada se nalazite na ekranu {screen}. Mogu objasniti ovaj dio modula, dostupne akcije i sljedeće korake.',
    'finance_assistant_q_what_is_screen': 'Čemu služi ovaj ekran?',
    'finance_assistant_q_next_step': 'Koji je moj sljedeći korak?',
    'finance_assistant_a_what_is_screen':
        'Nalazite se na ekranu {screen} unutar Finance & Controlling. Objašnjavam ovaj dio modula, dostupne akcije i dozvoljene korake — ne izvršavam radnje umjesto vas.',
    'finance_assistant_a_next_step':
        'Provjerite dostupne akcije na ekranu i status stavke. Za promjene koristite unos, knjiženje ili usklađivanje prema ulozi.',
    'finance_assistant_intro_default':
        'Finance asistent objašnjava trenutni ekran, pojmove i dozvoljene korake. Postavite pitanje ili odaberite prijedlog.',
    'finance_ai_analysis_title': 'Finance AI analiza',
    'finance_ai_analysis_tooltip': 'Finance AI analiza — uvidi i upozorenja',
    'finance_assistant_tab_overview': 'Pregled',
    'finance_assistant_tab_production': 'Proizvodnja',
    'finance_assistant_tab_downtime': 'Zastoji',
    'finance_assistant_tab_quality': 'Kvalitet',
    'finance_assistant_tab_maintenance': 'Održavanje',
    'finance_assistant_tab_procurement': 'Nabava',
    'finance_assistant_tab_budgets': 'Budžeti',
    'finance_assistant_tab_invoices': 'Fakture i otvorene stavke',
    'finance_assistant_tab_erp': 'ERP',
    'finance_assistant_screen_finance_controlling_dashboard': 'Pregled kontrolinga',
    'finance_assistant_screen_finance_controlling_production': 'Kontroling — proizvodnja',
    'finance_assistant_screen_finance_controlling_downtime': 'Kontroling — zastoji',
    'finance_assistant_screen_finance_controlling_quality': 'Kontroling — kvalitet',
    'finance_assistant_screen_finance_controlling_maintenance': 'Kontroling — održavanje',
    'finance_assistant_screen_finance_controlling_procurement': 'Kontroling — nabava',
    'finance_assistant_screen_finance_budgets': 'Budžeti',
    'finance_assistant_screen_finance_cash_flow_hub': 'Cash Flow',
    'finance_assistant_screen_finance_invoices_hub': 'Fakture i otvorene stavke',
    'finance_assistant_screen_finance_erp_hub': 'ERP integracije',
    'finance_assistant_screen_finance_erp_integrations_only': 'ERP integracije',
    'finance_assistant_screen_finance_accounts_list': 'Računi i blagajne',
    'finance_assistant_screen_finance_account_form': 'Unos računa',
    'finance_assistant_screen_finance_cash_flow_categories_list': 'Cash Flow kategorije',
    'finance_assistant_screen_finance_cash_flow_category_form': 'Unos kategorije',
    'finance_assistant_screen_finance_transactions_list': 'Transakcije',
    'finance_assistant_screen_finance_transaction_detail': 'Detalj transakcije',
    'finance_assistant_screen_finance_transaction_form': 'Unos transakcije',
    'finance_assistant_screen_finance_realized_cash_flow': 'Realizovani Cash Flow',
    'finance_assistant_screen_finance_planned_cash_items_list': 'Planirane stavke',
    'finance_assistant_screen_finance_planned_item_detail': 'Detalj planirane stavke',
    'finance_assistant_screen_finance_planned_item_form': 'Unos planirane stavke',
    'finance_assistant_screen_finance_cash_flow_forecast': 'Cash Flow prognoza',
    'finance_assistant_screen_finance_budget_vs_actual':
        'Budžet naspram realizacije i obrtni kapital',
    'finance_assistant_screen_finance_dso_dpo_ccc': 'DSO / DPO / CCC',
    'finance_assistant_screen_finance_sales_invoice_detail': 'Detalj izlazne fakture',
    'finance_assistant_screen_finance_sales_invoice_form': 'Unos izlazne fakture',
    'finance_assistant_screen_finance_purchase_invoices_list': 'Ulazne fakture',
    'finance_assistant_screen_finance_purchase_invoice_detail': 'Detalj ulazne fakture',
    'finance_assistant_screen_finance_purchase_invoice_form': 'Unos ulazne fakture',
    'finance_assistant_screen_finance_receivables_list': 'Potraživanja',
    'finance_assistant_screen_finance_payables_list': 'Obveze',
    'finance_assistant_screen_finance_allocate_payment': 'Alokacija uplate',
    'finance_assistant_screen_finance_payment_allocation_detail': 'Detalj alokacije',
    'finance_assistant_screen_finance_ai_assistant': 'Finance AI analiza',
    'finance_assistant_screen_finance_ai_alert_detail': 'Finance AI upozorenje',
    'finance_assistant_screen_finance_ai_notification_delivery_detail': 'Finance AI obavijest',
    'finance_assistant_offline_fallback':
        'Finance asistent Operonix Industrial trenutno nema vezu sa serverskom pomoći. Prikazano je osnovno objašnjenje ovog ekrana.',
    'finance_assistant_intro_bank_statements_list':
        'Tu sam da objasnim ovaj ekran i pomognem vam da povežete bankovne uplate ili isplate s fakturama. '
        'Ništa neću knjižiti niti potvrditi umjesto vas.',
    'finance_assistant_intro_bank_statement_detail':
        'Na detalju stavke vidite prijedloge, historiju potvrda i audit trag. '
        'Vodim vas kroz sljedeći korak — bez automatskih knjiženja.',
    'finance_assistant_intro_bank_match_confirm':
        'Ovdje ručno zadajete alokacije prije knjiženja. Provjerite iznose prije potvrde.',
    'finance_assistant_intro_bank_match_confirmation_detail':
        'Ovdje je audit zapis potvrde ili otkazivanja. Mogu objasniti reversal i alokacije.',
    'finance_assistant_intro_bank_match_suggestion_detail':
        'Prijedlog rangira fakture prema iznosu, referenci i partneru. Provjerite blocking razloge prije potvrde.',
    'finance_assistant_q_bank_list_purpose': 'Čemu služi ovaj ekran?',
    'finance_assistant_q_bank_generate': 'Šta znači Generiši prijedloge?',
    'finance_assistant_q_bank_why_suggested': 'Zašto je ova faktura predložena?',
    'finance_assistant_q_bank_confirm_effect': 'Šta će se desiti ako potvrdim?',
    'finance_assistant_q_bank_cancel_effect': 'Šta znači otkazivanje potvrde?',
    'finance_assistant_q_bank_next_step': 'Koji je moj sljedeći korak?',
    'finance_assistant_q_scenario_base_vs_pessimistic':
        'Koja je razlika između osnovnog i pesimističnog scenarija?',
    'finance_assistant_q_scenario_types':
        'Šta su osnovni, optimistični i pesimistični scenarij?',
    'finance_assistant_q_scenario_approve': 'Šta znači odobriti scenarij?',
    'finance_assistant_q_bawc_budget_vs_actual_period':
        'Objasni budžet naspram realizacije za ovaj period.',
    'finance_assistant_q_bawc_outflow_above_plan':
        'Zašto je realizovani odliv veći od plana?',
    'finance_assistant_q_bawc_unfavorable_variance':
        'Šta znači nepovoljno odstupanje?',
    'finance_assistant_q_bawc_variance_not_applicable':
        'Zašto procenat odstupanja nije primjenjiv?',
    'finance_assistant_q_bawc_net_cash_flow':
        'Objasni mi neto Cash Flow za ovaj period.',
    'finance_assistant_q_wc_dso_period_vs_average':
        'Koja je razlika između DSO na kraju perioda i prosječnih dana naplate?',
    'finance_assistant_q_wc_is_dso_good': 'Da li je 29 dana DSO dobro ili loše?',
    'finance_assistant_q_wc_dio_ccc_unavailable': 'Zašto DIO i CCC nisu dostupni?',
    'finance_assistant_q_wc_dpo_cash_impact': 'Kako DPO utiče na novčani tok?',
    'finance_assistant_q_wc_meaning_dso': 'Šta znači DSO?',
    'finance_assistant_q_wc_meaning_dpo': 'Šta znači DPO?',
    'finance_assistant_q_wc_meaning_dio': 'Šta znači DIO?',
    'finance_assistant_q_wc_meaning_ccc': 'Šta znači CCC?',
    'finance_assistant_q_wc_metrics_overview':
        'Objasni sve pokazatelje obrtnog kapitala.',
    'finance_assistant_intro_budget_vs_actual':
        'Objašnjavam usporedbu odobrenog budžeta s knjiženim Cash Flow transakcijama i DSO/DPO pokazatelje. '
        'Valute su samo EUR i BAM. Ne knjižim niti mijenjam podatke umjesto vas.',
    'finance_assistant_intro_dso_dpo_ccc':
        'Objašnjavam periodični DSO/DPO i prosječne dane stvarne naplate/plaćanja. '
        'DIO i CCC čekaju integraciju zaliha i COGS-a.',
    'finance_assistant_a_bank_list_purpose':
        'Šta znači: ovdje su uvezene bankovne stavke koje treba povezati s fakturama.\n\n'
        'Šta uraditi: filtrirajte period, otvorite stavku ili pokrenite import.\n\n'
        'Šta se dešava: import povlači nove stavke iz ERP-a; dalje radite uparivanje na detalju.',
    'finance_assistant_a_bank_generate':
        'Šta znači: Operonix traži fakture koje odgovaraju iznosu, referenci i partneru.\n\n'
        'Šta uraditi: na detalju stavke kliknite Generiši prijedloge.\n\n'
        'Šta se dešava: dobijate rangirane kandidate; vi odlučujete koji ide u potvrdu.',
    'finance_assistant_a_bank_why_suggested':
        'Šta znači: prijedlog je zasnovan na signali poput iznosa, broja fakture i reference plaćanja.\n\n'
        'Šta uraditi: otvorite prijedlog i provjerite blocking razloge (npr. valuta).\n\n'
        'Šta se dešava: loš prijedlog možete odbaciti; dobar vodi na Potvrdi.',
    'finance_assistant_a_bank_confirm_effect':
        'Šta znači: potvrda knjiži Cash Flow transakciju i alokacije na fakture.\n\n'
        'Šta uraditi: provjerite iznose, kategoriju i napomenu, zatim Potvrdi.\n\n'
        'Šta se dešava: bankovna stavka postaje djelimično ili potpuno usklađena; zapis ostaje u audit tragu.',
    'finance_assistant_a_bank_cancel_effect':
        'Šta znači: otkazivanje kreira reversal i vraća otvorene iznose faktura.\n\n'
        'Šta uraditi: unesite poslovni razlog otkazivanja.\n\n'
        'Šta se dešava: potvrda prelazi u otkazano; cijeli lanac ostaje vidljiv u historiji.',
    'finance_assistant_a_bank_next_step':
        'Šta uraditi: slijedite status stavke — import → prijedlozi → potvrda → usklađivanje.\n\n'
        'Ako je akcija nedostupna, provjerite ulogu i blocking razlog na prijedlogu.',
    'finance_assistant_a_scenario_base_vs_pessimistic':
        'Šta znači: osnovni scenarij polazi od Cash Flow prognoze i planiranih stavaka; '
        'pesimistični simulira kašnjenje naplate i veće odlive.\n\n'
        'Šta uraditi: usporedite oba scenarija ili otvorite usporedbu na Naprednoj Cash Flow analizi.\n\n'
        'Šta se dešava: razlika je vidljiva po periodu; odobreni scenarij ne mijenja transakcije.',
    'finance_assistant_a_scenario_types':
        'Šta znači: osnovni (referentni plan), optimistični (brža naplata), '
        'pesimistični (kašnjenje i veći odlivi) i Šta-ako (parametarska simulacija).\n\n'
        'Šta uraditi: kreirajte novi scenarij na Naprednoj Cash Flow analizi.',
    'finance_assistant_a_scenario_approve':
        'Šta znači: odobrenje znači da je scenarij prihvaćen za planiranje likvidnosti — ne knjiži transakcije.\n\n'
        'Šta uraditi: nakon izračuna provjerite pretpostavke i dodirnite Odobri na detalju scenarija.',
    'finance_assistant_a_bawc_outflow_above_plan':
        'Šta znači: realizovani odliv je zbroj knjiženih i usklađenih Cash Flow transakcija odliva; '
        'plan dolazi iz odobrenog budžeta za isti period, valutu i opseg pogona.\n\n'
        'Šta uraditi: usporedite planirani i realizovani odliv na kartici Budžet naspram realizacije.',
    'finance_assistant_a_bawc_budget_vs_actual_period':
        'Budžet naspram realizacije uspoređuje odobreni plan s knjiženim Cash Flow transakcijama '
        'za isti period, valutu i opseg pogona.',
    'finance_assistant_a_bawc_unfavorable_variance':
        'Šta znači: nepovoljno odstupanje znači manji priliv, veći odliv ili slabiji neto Cash Flow u odnosu na plan.\n\n'
        'Šta uraditi: pogledajte odstupanje po prilivu, odlivu i neto Cash Flow-u.',
    'finance_assistant_a_bawc_variance_not_applicable':
        'Šta znači: kad je plan nula, postotak odstupanja nema smisla — prikazuje se „Nije primjenjivo“.\n\n'
        'Šta uraditi: provjerite ima li odobrenog budžeta za period; fokusirajte se na apsolutni iznos odstupanja.',
    'finance_assistant_a_bawc_net_cash_flow':
        'Šta znači: neto Cash Flow = realizovani priliv minus realizovani odliv; planirani neto = planirani priliv minus planirani odliv.\n\n'
        'Šta uraditi: usporedite planirani i realizovani neto na kartici.',
    'finance_assistant_a_wc_dso_period_vs_average':
        'Šta znači: DSO na kraju perioda koristi otvorena potraživanja i kreditne prodaje; '
        'prosječni dani naplate računaju stvarne dane do potvrđene uplate za plaćene fakture.\n\n'
        'Šta uraditi: usporedite obje vrijednosti u dijelu Obrtni kapital.',
    'finance_assistant_a_wc_is_dso_good':
        'Šta znači: DSO nema univerzalni „dobar“ broj — ovisi o industriji i uvjetima plaćanja.\n\n'
        'Šta uraditi: usporedite DSO kroz vrijeme i s internim ciljem naplate.',
    'finance_assistant_a_wc_dio_ccc_unavailable':
        'Šta znači: DIO zahtijeva prosječnu vrijednost zaliha i kanonski trošak prodane robe; '
        'CCC nije dostupan bez DIO i ne smije se procijeniti samo kao DSO minus DPO.\n\n'
        'Šta uraditi: koristite dostupne DSO i DPO metrike; DIO/CCC dolaze nakon ERP/skladište integracije.',
    'finance_assistant_a_wc_dpo_cash_impact':
        'Šta znači: duži DPO zadržava novac duže u kompaniji; kraći DPO znači ranija plaćanja.\n\n'
        'Šta uraditi: usporedite obje DPO metrike s neto Cash Flow-om u dijelu Obrtni kapital.',
    'finance_assistant_a_wc_meaning_dso':
        'DSO — Days Sales Outstanding pokazuje za koliko dana se u prosjeku naplaćuju potraživanja od kupaca. '
        'Jednostavno: koliko dugo novac stoji kod kupaca prije nego što dođe na račun.',
    'finance_assistant_a_wc_meaning_dpo':
        'DPO — Days Payable Outstanding pokazuje za koliko dana se u prosjeku plaćaju dobavljači. '
        'Jednostavno: koliko dugo kompanija zadržava novac prije plaćanja obaveza.',
    'finance_assistant_a_wc_meaning_dio':
        'DIO — Days Inventory Outstanding pokazuje koliko dana kapital stoji vezan u zalihama. '
        'Za ovo trebaju pouzdani podaci o zalihama i trošku prodane robe.',
    'finance_assistant_a_wc_meaning_ccc':
        'CCC — Cash Conversion Cycle pokazuje koliko dana novac ostaje vezan u poslovnom ciklusu. '
        'Računa se tek kada postoje DIO, DSO i DPO: CCC = DIO + DSO − DPO.',
    'finance_assistant_a_wc_metrics_overview':
        'Pokazatelji obrtnog kapitala: DSO (naplata od kupaca), DPO (plaćanje dobavljačima), '
        'DIO (zalihe) i CCC (cijeli ciklus novca). DIO i CCC su „Nije dostupno“ dok nema ERP/skladište integracije.',
    'finance_assistant_a_free_text':
        'Za detaljno pitanje koristite predložena dugmad ili kontaktirajte administratora. '
        'Ja objašnjavam tok i pojmove — ne izvršavam knjiženja umjesto vas.',
    'finance_assistant_a_default':
        'Odaberite jedno od predloženih pitanja ili opišite što vas zbunjuje na ovom ekranu.',
    'help_finance_hub_tabs_title': 'Finance & Controlling — tabovi',
    'help_finance_hub_tabs_body':
        'Gornji tabovi dijele modul na cjeline:\n'
        '• Pregled — sažetak KPI i kontroling kartice za odabrano razdoblje.\n'
        '• Proizvodnja, Zastoji, Kvalitet, Održavanje, Nabava — agregati troškova i operativnih pokazatelja po domeni.\n'
        '• Budžeti — plan vs. stvarno po poslovnoj godini.\n'
        '• Cash Flow — operativni novac, računi, transakcije, bankovne stavke (ⓘ na svakoj kartici).\n'
        '• Fakture i otvorene stavke — izlazne/ulazne fakture, potraživanja i obaveze.\n'
        '• ERP — veza s računovodstvenim sustavom, sync i bankovni import.\n\n'
        'Na svakoj kartici unutar taba dodirnite ⓘ za detaljno objašnjenje bez ulaska u ekran.',
  };

  static const _en = <String, String>{
    'finance_hub_title': 'Finance',
    'finance_hub_subtitle':
        'Operational cash flow — accounts, categories and transactions (Callable layer).',
    'card_accounts_title': 'Accounts',
    'card_accounts_subtitle':
        'Bank accounts, cash registers and current cash balance.',
    'card_categories_title': 'Cash Flow categories',
    'card_categories_subtitle':
        'Category catalog for operating, investing and financing flows.',
    'module_not_enabled':
        'The finance_controlling module is not enabled for this company.',
    'access_denied': 'You do not have access to the Finance module.',
    'accounts_title': 'Accounts and cash registers',
    'accounts_empty': 'No accounts recorded.',
    'account_new': 'New account',
    'account_edit': 'Edit account',
    'account_code': 'Account code',
    'account_name': 'Name',
    'account_type': 'Account type',
    'currency': 'Currency',
    'finance_operating_currency_only': 'Only EUR and BAM are allowed.',
    'forecast_currency_exclusions_title':
        'Some items were excluded from the forecast (currency is not EUR or BAM)',
    'forecast_currency_exclusion_line': '{label} · {currency}',
    'opening_balance': 'Opening balance',
    'current_balance': 'Current balance',
    'bank_name': 'Bank',
    'iban': 'IBAN',
    'plant_key': 'Plant',
    'active': 'Active',
    'inactive': 'Inactive',
    'deactivate_account': 'Deactivate account',
    'deactivate_account_confirm':
        'The account will no longer be available for new transactions. Continue?',
    'save': 'Save',
    'cancel': 'Cancel',
    'refresh': 'Refresh',
    'categories_title': 'Cash Flow categories',
    'categories_empty': 'No categories.',
    'category_new': 'New category',
    'category_edit': 'Edit category',
    'category_code': 'Category code',
    'category_name': 'Category name',
    'activity_type': 'Activity type',
    'activity_operating': 'Operating activity',
    'activity_investing': 'Investing activity',
    'activity_financing': 'Financing activity',
    'sort_order': 'Sort order',
    'deactivate_category': 'Deactivate category',
    'deactivate_category_confirm':
        'The category will no longer be available for new entries. Continue?',
    'filter_active_only': 'Active only',
    'type_transactional': 'Transactional account',
    'type_foreign_currency': 'Foreign currency account',
    'type_cash_register': 'Cash register',
    'type_virtual': 'Virtual account',
    'type_credit_line': 'Credit line',
    'error_generic': 'Something went wrong. Please try again.',
    'error_function_not_found':
        'Bank statement service is unavailable (Cloud Function not deployed). '
        'Try again later or contact your administrator.',
    'error_parse': 'Invalid server response while loading data.',
    'error_server_internal':
        'Server error while loading data. Please try again in a few seconds.',
    'error_missing_company':
        'Company context is missing. Sign out and sign in again.',
    'saved': 'Saved.',
    'deactivated': 'Deactivated.',
    'pick_date': 'Pick date',
    'card_transactions_title': 'Transactions',
    'card_transactions_subtitle':
        'Drafts, posting, reconciliation and reversal of operational cash flows.',
    'card_realized_title': 'Realized Cash Flow',
    'card_realized_subtitle':
        'Summary of posted and reconciled transactions for the selected period.',
    'transactions_title': 'Transactions',
    'transactions_empty': 'No transactions for the selected filters.',
    'transaction_new': 'New transaction',
    'transaction_edit': 'Edit draft',
    'transaction_detail': 'Transaction details',
    'transaction_code': 'Transaction code',
    'transaction_date': 'Transaction date',
    'value_date': 'Value date',
    'amount': 'Amount',
    'direction': 'Direction',
    'direction_inflow': 'Inflow',
    'direction_outflow': 'Outflow',
    'status': 'Status',
    'tx_status_draft': 'Draft',
    'tx_status_planned': 'Planned',
    'tx_status_posted': 'Posted',
    'tx_status_reconciled': 'Reconciled',
    'tx_status_cancelled': 'Cancelled',
    'description': 'Description',
    'reference': 'Reference',
    'filter_status': 'Status',
    'filter_account': 'Account',
    'filter_direction': 'Direction',
    'filter_period': 'Period',
    'filter_all': 'All',
    'filter_all_accounts': 'All accounts',
    'date_from': 'Date from',
    'date_to': 'Date to',
    'account': 'Account',
    'category': 'Category',
    'post_transaction': 'Post',
    'post_transaction_confirm':
        'Posting changes the account balance. Continue?',
    'reconcile_transaction': 'Reconcile',
    'reconcile_transaction_confirm':
        'Reconciliation does not change the account balance. Continue?',
    'reverse_transaction': 'Reverse',
    'reverse_transaction_confirm':
        'Reversal creates a new transaction in the opposite direction. The original remains in history. Continue?',
    'cancel_draft': 'Cancel draft',
    'cancel_draft_confirm':
        'The draft will be cancelled without changing the balance. Continue?',
    'posted': 'Posted.',
    'reconciled': 'Reconciled.',
    'reversed': 'Reversal completed.',
    'draft_cancelled': 'Draft cancelled.',
    'audit_section': 'Audit trail',
    'audit_created_by': 'Created by',
    'audit_posted_by': 'Posted by',
    'audit_reconciled_by': 'Reconciled by',
    'audit_posted_at': 'Posted at',
    'audit_reconciled_at': 'Reconciled at',
    'link_reversal': 'Reversal transaction',
    'link_original': 'Original transaction',
    'realized_title': 'Realized Cash Flow',
    'realized_period': 'Period',
    'realized_total_inflows': 'Total inflows',
    'realized_total_outflows': 'Total outflows',
    'realized_net_cash_flow': 'Net cash flow',
    'realized_closing_balance': 'Closing balance',
    'realized_transaction_count': 'Transaction count',
    'realized_by_activity': 'By activity type',
    'realized_inflows': 'Inflows',
    'realized_outflows': 'Outflows',
    'realized_net': 'Net',
    'load_report': 'Load report',
    'select_account': 'Select account',
    'select_category': 'Select category',
    'select_direction': 'Select direction',
    'invoices_hub_subtitle':
        'Invoices, receivables and payables — Callable layer (P2).',
    'card_sales_invoices_title': 'Sales invoices',
    'card_sales_invoices_subtitle':
        'Drafts, issue and receivables per invoice.',
    'card_purchase_invoices_title': 'Purchase invoices',
    'card_purchase_invoices_subtitle':
        'Drafts, approval and payables per invoice.',
    'card_receivables_title': 'Receivables',
    'card_receivables_subtitle':
        'Open and partially paid sales invoices.',
    'card_payables_title': 'Payables',
    'card_payables_subtitle':
        'Open and partially paid purchase invoices.',
    'sales_invoices_title': 'Sales invoices',
    'sales_invoices_empty': 'No sales invoices.',
    'sales_invoice_new': 'New sales invoice',
    'sales_invoice_edit': 'Edit sales invoice draft',
    'purchase_invoices_title': 'Purchase invoices',
    'purchase_invoices_empty': 'No purchase invoices.',
    'purchase_invoice_new': 'New purchase invoice',
    'purchase_invoice_edit': 'Edit purchase invoice draft',
    'receivables_title': 'Receivables',
    'receivables_empty': 'No open receivables.',
    'receivables_open_list': 'Open and partially paid invoices',
    'payables_title': 'Payables',
    'payables_empty': 'No open payables.',
    'payables_open_list': 'Open and partially paid obligations',
    'customer_id': 'Customer code',
    'customer_name': 'Customer',
    'supplier_id': 'Supplier code',
    'supplier_name': 'Supplier',
    'net_amount': 'Net amount',
    'tax_amount': 'Tax amount',
    'total_amount': 'Total amount',
    'paid_amount': 'Paid',
    'open_amount': 'Open',
    'issue_date': 'Issue date',
    'due_date': 'Due date',
    'issue_sales_invoice': 'Issue invoice',
    'approve_purchase_invoice': 'Approve invoice',
    'cancel_invoice': 'Cancel invoice',
    'cancel_invoice_confirm':
        'The invoice will be cancelled per backend lifecycle rules. Continue?',
    'invoice_issued': 'Invoice issued.',
    'invoice_approved': 'Invoice approved.',
    'invoice_cancelled': 'Invoice cancelled.',
    'invoice_overdue': 'Overdue',
    'invoice_erp_synced': 'ERP',
    'invoice_erp_readonly_hint':
        'ERP-synced invoice: ERP-owned fields are not editable.',
    'open_items_count': 'Open invoice count',
    'open_items_total': 'Total open amount',
    'open_items_overdue_count': 'Overdue invoice count',
    'open_items_overdue_amount': 'Overdue amount',
    'inv_status_draft': 'Draft',
    'inv_status_open': 'Open',
    'inv_status_partial': 'Partially paid',
    'inv_status_paid': 'Paid',
    'inv_status_cancelled': 'Cancelled',
    'allocate_to_invoices': 'Allocate to invoices',
    'allocated_amount': 'Allocated',
    'unallocated_amount': 'Unallocated',
    'payment_allocations_section': 'Payment allocations',
    'allocations_empty': 'No allocations.',
    'allocations_active_total': 'Total actively allocated',
    'allocation_add_invoice': 'Add invoice',
    'allocation_lines_empty': 'Add one or more invoices to allocate.',
    'allocation_line_amount': 'Allocation amount',
    'allocation_invoice_remaining': 'Remaining open invoice amount',
    'allocation_batch_total': 'Allocation batch total',
    'allocation_remaining_tx': 'Remaining unallocated transaction amount',
    'allocation_confirm': 'Confirm allocation',
    'allocation_saved': 'Allocation saved.',
    'allocation_no_invoices': 'No matching open invoices.',
    'allocation_pick_sales_invoice': 'Select sales invoice',
    'allocation_pick_purchase_invoice': 'Select purchase invoice',
    'allocation_exceeds_unallocated':
        'Allocation total exceeds available unallocated amount.',
    'allocation_amount_required': 'Enter an allocation amount.',
    'allocation_amount_decimals': 'At most two decimal places.',
    'allocation_amount_invalid': 'Amount must be positive.',
    'allocation_cancel': 'Cancel allocation',
    'allocation_cancel_confirm': 'Cancel',
    'allocation_cancel_warning':
        'The account balance will not change. The invoice will regain its open amount. The original Cash Flow transaction remains posted. The allocation stays in history as cancelled.',
    'allocation_cancel_reason': 'Cancellation reason',
    'allocation_cancelled': 'Allocation cancelled.',
    'allocation_status_active': 'Active',
    'allocation_status_cancelled': 'Cancelled',
    'allocation_allocated_by': 'Allocated by',
    'allocation_allocated_at': 'Allocation date',
    'allocation_cancelled_at': 'Cancelled at',
    'allocation_cancelled_by': 'Cancelled by',
    'invoice_number': 'Invoice number',
    'card_planned_items_title': 'Planned items',
    'card_planned_items_subtitle':
        'Planned inflows and outflows with probability and approval lifecycle.',
    'card_forecast_title': 'Cash Flow forecast',
    'card_forecast_subtitle':
        'Deterministic cash flow forecast by buckets (Callable layer).',
    'card_advanced_cash_flow_title': 'Advanced Cash Flow analysis',
    'card_advanced_cash_flow_subtitle':
        'Liquidity scenarios on locked P3 forecast — preset and what-if.',
    'advanced_cash_flow_title': 'Advanced Cash Flow analysis',
    'scenario_new': 'New scenario',
    'scenario_edit': 'Edit scenario',
    'scenario_detail': 'Scenario detail',
    'scenario_name': 'Scenario name',
    'scenario_name_required': 'Scenario name is required.',
    'scenario_description': 'Description',
    'scenario_type': 'Scenario type',
    'scenario_plant_or_all': 'Plant (empty = all plants)',
    'scenario_filter_type': 'Scenario type',
    'scenario_filter_status': 'Status',
    'scenario_list_empty': 'No scenarios for the selected filters.',
    'scenario_list_closing': 'Closing balance: {amount}',
    'scenario_list_minimum': 'Minimum balance: {amount}',
    'scenario_list_meta': 'Version {version} · {updated} · {user}',
    'scenario_liquidity_warning': 'Warning: minimum liquidity threshold',
    'scenario_revision': 'Version {n}',
    'scenario_not_found': 'Scenario not found.',
    'scenario_period_required': 'Period from–to is required.',
    'scenario_preset_hint':
        'Assumptions for this scenario type come from the backend system preset.',
    'scenario_what_if_fields': 'What-if assumptions',
    'scenario_type_optimistic': 'Optimistic',
    'scenario_type_base': 'Base',
    'scenario_type_pessimistic': 'Pessimistic',
    'scenario_type_what_if': 'What-if',
    'scenario_status_draft': 'Draft',
    'scenario_status_calculated': 'Calculated',
    'scenario_status_approved': 'Approved',
    'scenario_status_archived': 'Archived',
    'scenario_section_base': 'Base forecast',
    'scenario_section_assumptions': 'Assumptions',
    'scenario_section_result': 'Result',
    'scenario_base_period': 'Forecast period',
    'scenario_actual_inflows': 'Actual inflows',
    'scenario_actual_outflows': 'Actual outflows',
    'scenario_planned_inflows': 'Planned inflows',
    'scenario_planned_outflows': 'Planned outflows',
    'scenario_currencies_used': 'Currencies used (opening account balances)',
    'scenario_assumption_preset': 'System preset',
    'scenario_assumption_user': 'User',
    'scenario_assumption_empty': '—',
    'scenario_assumption_value': 'Value',
    'scenario_unit_days': 'days',
    'scenario_unit_percent': '%',
    'scenario_unit_currency': 'currency',
    'scenario_result_closing': 'Projected closing balance',
    'scenario_result_minimum': 'Lowest balance in period',
    'scenario_result_minimum_date': 'Date of lowest balance',
    'scenario_result_periods_below': 'Periods below liquidity threshold',
    'scenario_result_inflows': 'Total projected inflows',
    'scenario_result_outflows': 'Total projected outflows',
    'scenario_result_by_currency': 'Balance by currency (backend source)',
    'scenario_comparison_title': 'Scenario comparison',
    'scenario_comparison_metric': 'Metric',
    'scenario_comparison_open': 'Full comparison view',
    'scenario_action_edit': 'Edit',
    'scenario_action_calculate': 'Calculate',
    'scenario_action_recalculate': 'Recalculate',
    'scenario_action_approve': 'Approve',
    'scenario_action_archive': 'Archive',
    'scenario_action_new_version': 'Create new version',
    'scenario_action_ok': 'Action completed successfully.',
    'scenario_assumption_receivableDelayDays_title': 'Receivable collection delay',
    'scenario_assumption_receivableDelayDays_body':
        'Positive = later collection in projection; negative = earlier. Does not change posted transactions.',
    'scenario_assumption_payableDelayDays_title': 'Payable payment delay',
    'scenario_assumption_payableDelayDays_body':
        'Positive = later payment; negative = earlier planned outflow projection.',
    'scenario_assumption_receivableProbabilityAdjustment_title':
        'Collection probability change',
    'scenario_assumption_receivableProbabilityAdjustment_body':
        'Adjustment to weighted inflow within allowed percent range.',
    'scenario_assumption_payableProbabilityAdjustment_title':
        'Payment probability change',
    'scenario_assumption_payableProbabilityAdjustment_body':
        'Adjustment to weighted outflow within allowed percent range.',
    'scenario_assumption_plannedInflowAdjustmentPercent_title':
        'Planned inflow increase or decrease',
    'scenario_assumption_plannedInflowAdjustmentPercent_body':
        'Percent change to planned nominal inflows; does not touch actual inflows.',
    'scenario_assumption_plannedOutflowAdjustmentPercent_title':
        'Planned outflow increase or decrease',
    'scenario_assumption_plannedOutflowAdjustmentPercent_body':
        'Percent change to planned nominal outflows; does not reduce posted outflows.',
    'scenario_assumption_minimumLiquidityThreshold_title': 'Minimum liquidity threshold',
    'scenario_assumption_minimumLiquidityThreshold_body':
        'Optional override of company minimumCashReserve for this scenario.',
    'help_card_advanced_cash_flow_title': 'Advanced Cash Flow analysis',
    'help_card_advanced_cash_flow_body':
        'Deterministic scenarios on locked P3 forecast: base, optimistic, pessimistic and what-if. Approved scenarios are not silently edited — new version creates a draft.',
    'help_advanced_cash_flow_tab_title': 'Advanced Cash Flow analysis',
    'bawc_title': 'Budget vs actual and working capital',
    'help_card_bawc_title': 'Budget vs actual and working capital',
    'help_card_bawc_body':
        'Planned vs realized cash flow and DSO/DPO metrics for the selected period — from backend snapshot.',
    'bawc_filter_plant': 'Plant',
    'bawc_currency': 'Currency',
    'bawc_section_budget': 'Budget vs actual',
    'bawc_section_working_capital': 'Working capital',
    'bawc_planned': 'Plan',
    'bawc_actual': 'Actual',
    'bawc_variance_amount': 'Variance (amount)',
    'bawc_variance_percent': 'Variance (%)',
    'bawc_variance_not_applicable': 'Not applicable',
    'bawc_metric_unavailable': 'Not available',
    'bawc_inflow': 'Inflow',
    'bawc_outflow': 'Outflow',
    'bawc_net_cash_flow': 'Net cash flow',
    'bawc_planned_inflow': 'Planned inflow',
    'bawc_actual_inflow': 'Actual inflow',
    'bawc_planned_outflow': 'Planned outflow',
    'bawc_actual_outflow': 'Actual outflow',
    'bawc_planned_net': 'Planned net',
    'bawc_actual_net': 'Actual net',
    'bawc_dso_period_end': 'DSO at period end',
    'bawc_dso_period_end_hint':
        'Periodic DSO: open receivables vs credit sales in the period, scaled to days.',
    'bawc_dso_collection_avg': 'Average collection days',
    'bawc_dso_collection_avg_hint':
        'Average actual days from issue to confirmed payment for fully paid invoices in the period.',
    'bawc_dpo_period_end': 'DPO at period end',
    'bawc_dpo_period_end_hint':
        'Periodic DPO: open payables vs debit purchases in the period, scaled to days.',
    'bawc_dpo_payment_avg': 'Average payment days',
    'bawc_dpo_payment_avg_hint':
        'Average actual days from approval to confirmed payment for fully paid purchase invoices in the period.',
    'bawc_dio': 'DIO',
    'bawc_ccc': 'CCC',
    'bawc_dio_ccc_unavailable':
        'Not available — canonical inventory data is missing',
    'bawc_dio_unavailable_cogs':
        'Not available — canonical cost of goods sold is missing',
    'bawc_ccc_unavailable_dso':
        'Not available — period-end DSO is missing',
    'bawc_ccc_unavailable_dpo':
        'Not available — period-end DPO is missing',
    'bawc_breakdown_title': 'Breakdown',
    'bawc_breakdown_period': 'By period',
    'bawc_breakdown_category': 'By category',
    'bawc_breakdown_plant': 'By plant',
    'bawc_period': 'Period',
    'bawc_category': 'Category',
    'bawc_plant': 'Plant',
    'bawc_uncategorized': 'Uncategorized',
    'bawc_coverage_title': 'Data coverage',
    'bawc_coverage_compact': '{count} data availability warnings',
    'bawc_warn_no_budget': 'No approved budget for the selected period.',
    'bawc_warn_no_collection_payments':
        'No confirmed payments for average collection days.',
    'bawc_warn_no_payment_payments':
        'No confirmed payments for average payment days.',
    'bawc_warn_dio_ccc_unavailable':
        'DIO and CCC are not available because inventory data is not linked yet.',
    'bawc_warn_dio_unavailable_inventory':
        'DIO is not available because canonical inventory data is missing.',
    'bawc_warn_dio_unavailable_cogs':
        'DIO is not available because canonical cost of goods sold is missing.',
    'bawc_warn_ccc_unavailable':
        'CCC is not available because period-end DSO or DPO is missing.',
    'bawc_warn_inventory_erp_preferred':
        'ERP is used for inventory because it takes precedence over WMS.',
    'bawc_warn_cogs_erp_preferred':
        'ERP is used for cost of goods sold because it takes precedence over WMS.',
    'bawc_warn_budget_incomplete':
        'Some budget lines were excluded because period or cash flow direction is missing.',
    'bawc_empty_hint': 'Select period and currency, then tap Refresh.',
    'bawc_empty_period': 'No data for the selected period and filters.',
    'planned_items_title': 'Planned items',
    'planned_items_empty': 'No planned items for the selected filters.',
    'planned_item_new': 'New planned item',
    'planned_item_edit': 'Edit planned item draft',
    'planned_item_detail': 'Planned item details',
    'planned_status_draft': 'Draft',
    'planned_status_approved': 'Approved',
    'planned_status_cancelled': 'Cancelled',
    'expected_date': 'Expected date',
    'nominal_amount': 'Nominal amount',
    'weighted_amount': 'Weighted amount',
    'probability_percent': 'Probability (%)',
    'probability_source': 'Probability source',
    'prob_source_manual_confirmed': 'Manually confirmed',
    'prob_source_company_rule': 'Company rule',
    'prob_source_system_default': 'System default',
    'approve_planned_item': 'Approve item',
    'approve_planned_item_confirm':
        'Approved items enter the forecast. Canonical fields cannot be edited after approval. Continue?',
    'cancel_planned_item': 'Cancel item',
    'cancel_planned_item_confirm':
        'The item will no longer appear in the forecast. Continue?',
    'planned_item_approved': 'Planned item approved.',
    'planned_item_cancelled': 'Planned item cancelled.',
    'planned_readonly_hint':
        'Approved items are read-only. Correction: cancel + new item.',
    'forecast_title': 'Cash Flow forecast',
    'forecast_horizon': 'Horizon (days)',
    'forecast_custom_period': 'Custom period',
    'forecast_use_horizon': 'Preset horizon',
    'forecast_use_custom': 'Custom period',
    'forecast_bucket_type': 'Bucket type',
    'forecast_bucket_day': 'Day',
    'forecast_bucket_week': 'Week',
    'forecast_bucket_month': 'Month',
    'forecast_opening_balance': 'Opening balance',
    'forecast_actual_inflows': 'Actual inflows',
    'forecast_actual_outflows': 'Actual outflows',
    'forecast_planned_nominal_inflows': 'Planned nominal inflows',
    'forecast_planned_nominal_outflows': 'Planned nominal outflows',
    'forecast_planned_weighted_inflows': 'Planned weighted inflows',
    'forecast_planned_weighted_outflows': 'Planned weighted outflows',
    'forecast_nominal_closing': 'Nominal closing balance',
    'forecast_weighted_closing': 'Weighted closing balance',
    'forecast_buckets_empty': 'No buckets for the selected parameters.',
    'forecast_minimum_cash_reserve': 'Minimum cash reserve',
    'forecast_first_below_reserve_nominal': 'First nominal below reserve',
    'forecast_first_below_reserve_weighted': 'First weighted below reserve',
    'forecast_min_nominal_balance': 'Minimum nominal balance',
    'forecast_min_nominal_balance_date': 'Minimum nominal balance date',
    'forecast_min_weighted_balance': 'Minimum weighted balance',
    'forecast_min_weighted_balance_date': 'Minimum weighted balance date',
    'forecast_negative_nominal_expected': 'Negative nominal balance expected',
    'forecast_negative_weighted_expected': 'Negative weighted balance expected',
    'forecast_yes': 'Yes',
    'forecast_no': 'No',
    'forecast_load': 'Load forecast',
    'forecast_period_label': 'Forecast period',
    'advisory_section_title': 'Proactive financial monitoring',
    'advisory_controlling_section_title': 'Controlling AI analysis',
    'advisory_empty': 'No alerts for the selected filters.',
    'advisory_load_error': 'Failed to load alerts.',
    'advisory_alert_not_found':
        'This alert is no longer available. It may have been resolved or removed.',
    'advisory_filter_status': 'Status',
    'advisory_filter_severity': 'Severity',
    'advisory_filter_plant': 'Plant',
    'advisory_filter_active': 'Active alerts',
    'advisory_filter_history': 'History',
    'advisory_filter_all_plants': 'All plants',
    'advisory_filter_all_severities': 'All levels',
    'advisory_run_analysis': 'Analyze now',
    'advisory_run_analysis_running': 'Analysis in progress…',
    'advisory_run_summary':
        'Rules evaluated: {rules} · new: {created} · updated: {updated} · resolved: {resolved} · skipped: {skipped}',
    'advisory_confidence_label': 'Confidence: {score}%',
    'advisory_confidence_score': 'Confidence',
    'advisory_plant_scope': 'Plant: {plant}',
    'advisory_detected_range': 'First detected: {first} · last: {last}',
    'advisory_severity_info': 'Info',
    'advisory_severity_medium': 'Medium',
    'advisory_severity_high': 'High',
    'advisory_severity_critical': 'Critical',
    'advisory_status_open': 'Open',
    'advisory_status_acknowledged': 'Acknowledged',
    'advisory_status_resolved': 'Resolved',
    'advisory_status_dismissed': 'Dismissed',
    'advisory_detail_title': 'Alert detail',
    'advisory_section_observed': 'What did Operonix notice?',
    'advisory_section_why': 'Why is Operonix showing this?',
    'advisory_section_assessment': 'Assessment',
    'advisory_section_recommendation': 'Recommended next action',
    'advisory_confidence_origin': 'Confidence origin',
    'advisory_confidence_factors': 'Confidence factors',
    'advisory_analysis_date': 'Analysis date',
    'advisory_facts_empty': 'No facts available for this alert.',
    'advisory_fact_as_of': 'As of: {date}',
    'advisory_acknowledge': 'Mark as reviewed',
    'advisory_acknowledged': 'Alert marked as reviewed.',
    'advisory_dismiss': 'Dismiss alert',
    'advisory_dismissed': 'Alert dismissed.',
    'advisory_feedback': 'Send feedback',
    'advisory_feedback_title': 'Alert feedback',
    'advisory_feedback_helpful': 'Accurate',
    'advisory_feedback_not_helpful': 'Partially accurate',
    'advisory_feedback_incorrect_facts': 'Incorrect',
    'advisory_feedback_wrong_severity': 'Not relevant',
    'advisory_feedback_comment': 'Comment (optional)',
    'advisory_feedback_submit': 'Submit feedback',
    'advisory_feedback_sent': 'Feedback received.',
    'advisory_dismiss_title': 'Dismiss reason',
    'advisory_dismiss_confirm': 'Dismiss alert',
    'advisory_dismiss_other': 'Describe the reason',
    'advisory_dismiss_reason_risk_resolved': 'Risk already resolved',
    'advisory_dismiss_reason_known_circumstance': 'Known business circumstance',
    'advisory_dismiss_reason_incorrect_incomplete_data':
        'Incorrect or incomplete data',
    'advisory_dismiss_reason_not_relevant': 'Not relevant',
    'advisory_dismiss_reason_other': 'Other reason',
    'advisory_open_recommendation': 'Open recommended screen',
    'advisory_section_decision': 'Recommendation decision',
    'advisory_accept_recommendation': 'Accept recommendation',
    'advisory_reject_recommendation': 'Reject recommendation',
    'advisory_decision_accepted': 'Recommendation accepted.',
    'advisory_decision_rejected': 'Recommendation rejected.',
    'advisory_reject_title': 'Reason for rejecting recommendation',
    'advisory_reject_confirm': 'Reject recommendation',
    'advisory_reject_other': 'Describe the reason',
    'advisory_reject_reason_not_relevant': 'Not relevant',
    'advisory_reject_reason_already_resolved': 'Already resolved',
    'advisory_reject_reason_incorrect_incomplete_data':
        'Incorrect or incomplete data',
    'advisory_reject_reason_other_business_decision': 'Other business decision',
    'advisory_reject_reason_other': 'Other reason',
    'advisory_section_outcome': 'Recommendation outcome',
    'advisory_outcome_empty': 'Outcome is not available yet.',
    'advisory_outcome_load_error': 'Failed to load outcome.',
    'advisory_telemetry_error': 'Telemetry was not recorded. Please retry.',
    'advisory_outcome_status': 'Outcome status',
    'advisory_outcome_observation_window': 'Observation window',
    'advisory_outcome_next_evaluation': 'Next evaluation',
    'advisory_outcome_attribution': 'Attribution',
    'advisory_outcome_confirmation_method': 'Confirmation method',
    'advisory_outcome_confirmed_impact': 'Confirmed financial impact',
    'advisory_outcome_evidence_title': 'Evidence records',
    'advisory_outcome_evidence_before': 'Initial value',
    'advisory_outcome_evidence_after': 'Final value',
    'advisory_outcome_evidence_observed_at': 'Observation time',
    'advisory_outcome_value_unavailable': 'Not available',
    'advisory_outcome_status_outcome_pending': 'Outcome under observation',
    'advisory_outcome_status_outcome_confirmed': 'Outcome confirmed by facts',
    'advisory_outcome_status_outcome_not_confirmed':
        'Recommended outcome not confirmed',
    'advisory_outcome_status_outcome_unknown': 'Insufficient evidence',
    'advisory_outcome_message_outcome_pending':
        'The outcome is still under observation.',
    'advisory_outcome_message_outcome_confirmed':
        'The outcome was confirmed using operational data.',
    'advisory_outcome_message_outcome_not_confirmed':
        'The recommended outcome was not confirmed during observation.',
    'advisory_outcome_message_outcome_unknown':
        'There is not enough evidence to confirm or reject the outcome.',
    'advisory_outcome_attribution_direct': 'Direct',
    'advisory_outcome_attribution_contributing': 'Contributing',
    'advisory_outcome_attribution_uncertain': 'Uncertain',
    'advisory_outcome_attribution_not_attributable': 'Not attributable',
    'advisory_outcome_confirmation_overdue_amount_reduction':
        'Overdue amount reduction',
    'advisory_outcome_confirmation_invoice_payment_timing':
        'Invoice payment timing',
    'advisory_outcome_confirmation_forecast_risk_removed':
        'Forecast risk removed',
    'advisory_outcome_evidence_overdue_amount': 'Overdue amount',
    'advisory_outcome_evidence_open_amount': 'Open amount',
    'advisory_outcome_evidence_forecast_signal': 'Liquidity forecast signal',
    'retry': 'Retry',
    'more_actions': 'More actions',
    'advisory_resolution_reason': 'Resolution reason',
    'advisory_dismiss_reason_label': 'Dismiss reason',
    'advisory_origin_deterministic_only': 'Assessment from business data',
    'advisory_origin_deterministic_with_ai_interpretation':
        'Assessment from data with AI explanation',
    'advisory_origin_insufficient_facts':
        'Insufficient data for a reliable assessment',
    'advisory_snapshot_threshold': 'Operating threshold',
    'advisory_snapshot_minimum_cash_reserve': 'Minimum cash reserve',
    'advisory_snapshot_base_currency': 'Base currency',
    'advisory_snapshot_first_nominal_below_reserve_date':
        'First date below reserve (nominal)',
    'advisory_snapshot_first_weighted_below_reserve_date':
        'First date below reserve (weighted)',
    'advisory_snapshot_minimum_nominal_balance': 'Lowest nominal balance',
    'advisory_snapshot_minimum_weighted_balance': 'Lowest weighted balance',
    'advisory_snapshot_nominal_negative_balance_expected':
        'Negative balance expected (nominal)',
    'advisory_snapshot_weighted_negative_balance_expected':
        'Negative balance expected (weighted)',
    'advisory_snapshot_customer_name': 'Customer',
    'advisory_snapshot_supplier_name': 'Supplier',
    'advisory_snapshot_direction': 'Direction',
    'advisory_snapshot_allocated_amount': 'Allocated amount',
    'advisory_snapshot_unallocated_amount': 'Unallocated amount',
    'advisory_snapshot_nominal_amount': 'Nominal amount',
    'advisory_snapshot_status': 'Status',
    'advisory_factor_fact_completeness': 'Data completeness',
    'advisory_factor_forecast_horizon_days': 'Forecast horizon',
    'advisory_factor_signal_strength': 'Signal strength',
    'advisory_factor_data_freshness': 'Data freshness',
    'advisory_factor_days_one': '1 day',
    'advisory_factor_days_many': '{count} days',
    'advisory_freshness_current': 'Current data',
    'advisory_freshness_minutes': '{count} min ago',
    'advisory_freshness_hours': '{count} h ago',
    'advisory_rule_liquidity_below_minimum_reserve_nominal':
        'Liquidity below minimum reserve (nominal)',
    'advisory_rule_liquidity_below_minimum_reserve_weighted':
        'Liquidity below minimum reserve (weighted)',
    'advisory_rule_liquidity_negative_balance_expected_nominal':
        'Negative balance expected (nominal)',
    'advisory_rule_liquidity_negative_balance_expected_weighted':
        'Negative balance expected (weighted)',
    'advisory_rule_receivables_overdue_material':
        'Material overdue receivables',
    'advisory_rule_payables_due_soon_cluster': 'Payables due soon cluster',
    'advisory_rule_cash_unallocated_surplus': 'Unallocated cash surplus',
    'advisory_rule_planned_items_draft_backlog': 'Draft planned items backlog',
    'advisory_rule_accounts_low_balance_single': 'Low single account balance',
    'advisory_fact_forecast_liquidity_threshold':
        'Liquidity threshold from forecast',
    'advisory_fact_sales_invoice_open': 'Open sales invoice',
    'advisory_fact_purchase_invoice_open': 'Open purchase invoice',
    'advisory_fact_cash_transaction': 'Cash transaction',
    'advisory_fact_planned_cash_item': 'Planned cash item',
    'advisory_fact_account_balance': 'Account balance',
    'kpi_section_title': 'AI recommendation results',
    'kpi_section_subtitle':
        'Measurable Finance AI recommendation outcomes for the selected period (read-only snapshot).',
    'kpi_period_from': 'Period from',
    'kpi_period_to': 'Period to',
    'kpi_scope_line': 'Scope: {scope} · {from} – {to}',
    'kpi_load_error': 'Failed to load KPI results.',
    'kpi_empty_period': 'No interactions or evaluated outcomes for the selected period.',
    'kpi_insufficient_data': 'Insufficient data',
    'kpi_section_engagement': 'Engagement',
    'kpi_shown_count': 'Recommendations shown',
    'kpi_viewed_count': 'Recommendations viewed',
    'kpi_accepted_count': 'Recommendations accepted',
    'kpi_rejected_count': 'Recommendations rejected',
    'kpi_viewed_rate': 'View rate',
    'kpi_acceptance_rate': 'Acceptance rate',
    'kpi_viewed_label': 'viewed',
    'kpi_shown_label': 'shown',
    'kpi_accepted_label': 'accepted',
    'kpi_decision_label': 'decisions (accepted + rejected)',
    'kpi_section_execution': 'Recommendation execution',
    'kpi_action_started_count': 'Actions started',
    'kpi_action_completed_count': 'Actions completed',
    'kpi_action_start_rate': 'Action start rate',
    'kpi_action_completion_rate': 'Action completion rate',
    'kpi_action_started_label': 'started',
    'kpi_action_completed_label': 'completed',
    'kpi_avg_time_to_action': 'Average time to completed action',
    'kpi_avg_time_pairs': 'Based on {count} shown → action_completed pairs',
    'kpi_duration_hours_minutes': '{hours} h {minutes} min',
    'kpi_duration_minutes': '{minutes} min',
    'kpi_duration_under_minute': 'Less than 1 min',
    'kpi_section_outcomes': 'Outcomes',
    'kpi_outcome_confirmed_count': 'Confirmed outcomes',
    'kpi_outcome_not_confirmed_count': 'Not confirmed outcomes',
    'kpi_outcome_not_confirmed_hint':
        'The recommended result was not confirmed in the observation window.',
    'kpi_outcome_unknown_count': 'Unknown outcomes',
    'kpi_outcome_unknown_hint': 'Insufficient evidence to confirm or reject the outcome.',
    'kpi_confirmed_outcome_rate': 'Confirmed outcome rate',
    'kpi_positive_confirmed_outcome_rate': 'Positive confirmed outcome rate',
    'kpi_outcome_unknown_rate': 'Unknown outcome rate',
    'kpi_outcome_confirmed_label': 'confirmed',
    'kpi_outcome_evaluated_label': 'evaluated',
    'kpi_positive_outcome_label': 'positive with financial result',
    'kpi_financial_result_label': 'with deterministic financial result',
    'kpi_positive_outcome_hint':
        'Confirmed outcomes without financial effect (null) are excluded from the numerator.',
    'kpi_outcome_unknown_label': 'unknown',
    'kpi_section_rejection': 'Rejection reasons',
    'kpi_rejection_empty': 'No rejected recommendations in the period.',
    'kpi_section_attribution': 'Outcome attribution',
    'kpi_attribution_eligible_hint':
        'Direct and contributing count toward confirmed AI recommendation financial effect.',
    'kpi_attribution_excluded_hint':
        'Uncertain and not attributable are excluded from confirmed financial effect.',
    'kpi_attribution_impact_note':
        'Amounts below include direct/contributing attribution only.',
    'kpi_confirmed_impact_title': 'Confirmed financial effect of AI recommendations',
    'kpi_confirmed_impact_subtitle':
        'Only deterministically confirmed amounts from outcome evaluation.',
    'kpi_confirmed_impact_empty':
        'No confirmed financial effect for the selected period and scope.',
    'kpi_multi_currency_warning':
        'Multiple currencies present — amounts are not summed without canonical conversion.',
    'kpi_base_currency_total': 'Total in base currency ({currency})',
    'kpi_contract_info_title': 'KPI contract',
    'kpi_contract_version': 'Contract version',
    'kpi_evaluator_version': 'Evaluator version',
    'kpi_contract_sources': 'Source collections:',
    'kpi_neutral_disclaimer':
        'These KPIs measure Finance AI recommendation effectiveness, not overall company financial results.',
    'notification_section_title': 'In-app notifications',
    'notification_empty': 'No notifications for the selected filters.',
    'notification_load_error': 'Failed to load notifications.',
    'notification_filter_active': 'Active',
    'notification_filter_history': 'History',
    'notification_filter_all': 'All',
    'notification_filter_unread': 'Unread',
    'notification_scope_company_wide': 'Entire company',
    'notification_plant_scope': 'Plant: {plant}',
    'notification_scope_label': 'Scope',
    'notification_delivered_at': 'Delivered: {time}',
    'notification_generation_revision': 'Generation {gen} · revision {rev}',
    'notification_detail_title': 'Notification detail',
    'notification_delivery_status': 'Delivery status',
    'notification_mark_read': 'Mark as read',
    'notification_marked_read': 'Notification marked as read.',
    'notification_open_alert': 'Open linked alert',
    'notification_alert_unavailable':
        'The linked alert is no longer in the system. Notification details are shown below.',
    'notification_closed_reason': 'Close reason',
    'notification_status_unread': 'Unread',
    'notification_status_read': 'Read',
    'notification_status_acknowledged': 'Acknowledged',
    'notification_status_superseded': 'Superseded',
    'notification_status_closed': 'Closed',
    'card_bank_statements_title': 'Bank statement lines',
    'card_bank_statements_subtitle':
        'ERP import, line review, match suggestions and reconciliation confirmation.',
    'bank_statements_title': 'Bank statement lines',
    'bank_statements_empty': 'No bank lines for the selected filters.',
    'bank_import': 'Run import',
    'bank_import_title': 'Import bank statement lines',
    'bank_import_connection': 'ERP connection',
    'bank_import_account': 'Bank account',
    'bank_import_started': 'Import started.',
    'bank_import_status': 'Import status',
    'bank_import_success': 'Bank statement lines imported successfully.',
    'bank_import_success_detail':
        'Import completed: {created} new, {updated} updated lines.',
    'bank_import_partial':
        'Import partially succeeded ({failed} errors). Check the sync log.',
    'bank_import_failed': 'Bank statement import failed.',
    'bank_ignore': 'Ignore line',
    'bank_restore': 'Restore ignored line',
    'bank_ignore_reason': 'Ignore reason',
    'bank_detail_title': 'Bank line',
    'bank_booking_date': 'Booking date',
    'bank_value_date': 'Value date',
    'bank_counterparty': 'Partner / payer',
    'bank_reference': 'Payment reference',
    'bank_description': 'Description',
    'bank_status_imported': 'Imported',
    'bank_status_unmatched': 'Unmatched',
    'bank_status_suggested': 'Has suggestions',
    'bank_status_confirmed': 'Confirmed',
    'bank_status_posted': 'Posted',
    'bank_status_partially_reconciled': 'Partially reconciled',
    'bank_status_reconciled': 'Reconciled',
    'bank_status_ignored': 'Ignored',
    'bank_match_suggestions_title': 'Match suggestions',
    'bank_match_suggestions_empty': 'No suggestions for this line.',
    'bank_match_generate': 'Generate suggestions',
    'bank_match_generate_success': 'Generated {count} suggestion(s).',
    'bank_match_generate_none': 'No new match candidates found.',
    'bank_match_generate_skipped_reconciled':
        'Reconciled/posted line — new suggestions are not generated.',
    'bank_match_suggestions_empty_reconciled':
        'Line is already reconciled — suggestions are no longer needed.',
    'bank_match_score': 'Score',
    'bank_match_confidence': 'Confidence',
    'bank_match_open_amount': 'Invoice open amount',
    'bank_match_signals': 'Business signals',
    'bank_match_blocking': 'Blocking reasons',
    'bank_match_dismiss': 'Dismiss suggestion',
    'bank_match_restore_suggestion': 'Restore dismissed suggestion',
    'bank_match_dismiss_reason': 'Dismiss reason',
    'bank_match_continue_confirm': 'Continue to confirmation',
    'bank_match_blocked_hint':
        'This suggestion has blocking reasons and cannot be confirmed.',
    'bank_match_confirm_title': 'Confirm match',
    'bank_match_confirm_preview': 'Preview before confirm',
    'bank_match_bank_amount': 'Bank line',
    'bank_match_allocated': 'Allocated',
    'bank_match_unallocated': 'Unallocated',
    'bank_match_result_partial': 'Result: partially reconciled',
    'bank_match_result_full': 'Result: fully reconciled',
    'bank_match_result_over': 'Allocation exceeds line amount',
    'bank_match_category': 'Cash Flow category',
    'bank_match_note': 'Note',
    'bank_match_add_line': 'Add invoice',
    'bank_match_confirm_submit': 'Confirm match',
    'bank_match_confirmations_title': 'Confirmation history',
    'bank_match_confirmations_empty': 'No confirmations for this line.',
    'bank_match_confirmation_detail': 'Confirmation detail',
    'bank_match_confirmation_unlabeled': 'Match confirmation',
    'bank_match_confirmed_by': 'Confirmed by',
    'bank_match_confirmed_at': 'Confirmed at',
    'bank_match_cash_transaction': 'Cash Flow transaction',
    'bank_match_allocations': 'Invoice allocations',
    'bank_match_cancel': 'Cancel confirmation',
    'bank_match_cancel_confirm_title': 'Cancel match confirmation',
    'bank_match_cancel_confirm_body':
        'Operonix Industrial will create a reversal Cash Flow entry, void related allocations, restore invoice open amounts and keep a full audit trail. No data will be deleted.',
    'bank_match_cancel_reason': 'Cancellation reason',
    'bank_match_cancel_result_title': 'Cancellation result',
    'bank_match_cancelled_at': 'Cancelled at',
    'bank_match_cancelled_by': 'Cancelled by',
    'bank_match_reversal_txn': 'Reversal transaction',
    'bank_match_cancelled': 'Confirmation cancelled.',
    'bank_audit_trail_title': 'History and audit trail',
    'bank_audit_trail_empty': 'No audit records for this bank line.',
    'bank_audit_trail_tap_detail': 'Tap for before/after and related records',
    'audit_performed_by': 'Performed by',
    'audit_entity_type': 'Entity type',
    'audit_source': 'Source',
    'audit_request_id': 'Request ID',
    'audit_related_entities': 'Related records',
    'audit_before': 'Before',
    'audit_after': 'After',
    'audit_action_bank_statement_import_create': 'Bank line imported',
    'audit_action_bank_statement_import_update': 'Bank line updated from ERP',
    'audit_action_bank_statement_ignore': 'Bank line ignored',
    'audit_action_bank_statement_restore': 'Bank line restored from ignored',
    'audit_action_bank_statement_status_suggested': 'Line status: suggestions available',
    'audit_action_bank_match_suggestion_create': 'Match suggestion generated',
    'audit_action_bank_match_suggestion_refresh': 'Match suggestion refreshed',
    'audit_action_bank_match_suggestion_dismiss': 'Match suggestion dismissed',
    'audit_action_bank_match_suggestion_restore': 'Dismissed suggestion restored',
    'audit_action_bank_match_confirm': 'Match confirmation created',
    'audit_action_bank_match_post': 'Bank line reconciled (posted)',
    'audit_action_bank_match_allocate': 'Invoice allocation created',
    'audit_action_bank_match_cancel': 'Match confirmation cancelled',
    'audit_action_cancel': 'Allocation voided',
    'audit_source_manual': 'Manual user action',
    'audit_source_scheduled': 'Scheduled job',
    'audit_source_system': 'System',
    'audit_entity_finance_bank_statement_transactions': 'Bank statement line',
    'audit_entity_finance_bank_match_confirmations': 'Match confirmation',
    'audit_entity_finance_bank_match_suggestions': 'Match suggestion',
    'audit_entity_finance_payment_allocation': 'Payment allocation',
    'audit_entity_finance_cash_transactions': 'Cash Flow transaction',
    'bank_match_confidence_high': 'High confidence',
    'bank_match_confidence_medium': 'Medium confidence',
    'bank_match_confidence_low': 'Low confidence',
    'bank_match_intro_primary':
        'Operonix Industrial found possible invoices for this bank line. '
        'Review high-confidence suggestions first and check match reasons before confirming.',
    'bank_match_show_weak': 'Show weak suggestions ({count})',
    'bank_match_hide_weak': 'Hide weak suggestions',
    'bank_match_card_open': 'Open amount',
    'bank_match_card_title': 'Invoice {number} — {partner}',
    'bank_match_card_bank_payment': 'Bank inflow',
    'bank_match_card_bank_payout': 'Bank outflow',
    'bank_match_amount_diff_none': 'Amounts match',
    'bank_match_amount_diff_over': 'Bank amount exceeds by {amount}',
    'bank_match_amount_diff_under': 'Bank amount is short by {amount}',
    'bank_match_top_reasons': 'Reasons',
    'bank_match_tap_for_detail': 'Tap for detailed comparison',
    'bank_match_detail_title': 'Suggestion comparison',
    'bank_match_detail_bank_section': 'Bank line',
    'bank_match_detail_invoice_section': 'Invoice',
    'bank_match_detail_why': 'Why suggested',
    'bank_match_detail_warnings': 'Warnings',
    'bank_match_detail_invoice_total': 'Invoice gross amount',
    'bank_match_detail_invoice_due': 'Due date',
    'bank_match_detail_partner_account': 'Partner account',
    'bank_match_detail_invoice_type_sales': 'Sales invoice',
    'bank_match_detail_invoice_type_purchase': 'Purchase invoice',
    'bank_match_detail_invoice_number': 'Invoice number',
    'bank_match_detail_back': 'Back to other suggestions',
    'bank_match_detail_blocked_title': 'Confirmation not allowed',
    'bank_match_dismissed_section': 'Dismissed suggestions',
    'bank_match_hidden_useful_hint':
        '{count} more useful suggestions are hidden — show weak list or regenerate.',
    'bank_match_sentence_invoice_number_exact':
        'Invoice number found in payment reference',
    'bank_match_sentence_payment_reference_exact':
        'Payment reference fully matches the invoice',
    'bank_match_sentence_exact_amount':
        'Bank line amount fully matches the invoice open amount',
    'bank_match_sentence_partial_amount':
        'Bank line amount partially covers the invoice open amount',
    'bank_match_sentence_partner_account_exact':
        'Partner bank account matches',
    'bank_match_sentence_partner_name_normalized':
        'Partner name matches',
    'bank_match_sentence_due_date_proximity':
        'Payment date is close to the invoice due date',
    'bank_match_sentence_booking_date_proximity':
        'Booking date is close to the invoice due date',
    'bank_match_sentence_currency_exact': 'Currency matches',
    'bank_match_sentence_open_amount_compatible':
        'Invoice open amount is compatible with the bank line',
    'bank_match_warn_low_score':
        'Low confidence — verify manually before confirming',
    'bank_match_warn_amount_diff': 'Amount differs from invoice open amount',
    'bank_match_warn_partner_weak':
        'Partner not reliably matched (name only, no account or amount match)',
    'bank_match_warn_currency_date_only':
        'Mostly currency and/or date proximity only',
    'bank_match_block_sentence_currency_mismatch':
        'Invoice and bank line currencies do not match',
    'bank_match_block_sentence_invoice_closed': 'Invoice is already closed',
    'bank_match_block_sentence_invoice_conflict_requires_review':
        'Invoice has a sync conflict requiring review',
    'bank_match_block_sentence_bank_transaction_ignored': 'Bank line is ignored',
    'bank_match_block_sentence_bank_transaction_already_posted':
        'Bank line is already posted or reconciled',
    'bank_match_block_sentence_invalid_direction':
        'Invoice type does not match bank line direction',
    'bank_match_block_sentence_missing_open_amount': 'Invoice has no open amount',
    'concurrency_refresh_hint':
        'Data was refreshed below. Review amounts and press Confirm match again.',
    'bank_match_confirm_not_saved':
        'Match was not confirmed — nothing was saved.',
    'filter_currency': 'Currency',
    'bank_signal_exact_amount': 'Exact amount',
    'bank_signal_partial_amount': 'Partial amount',
    'bank_signal_invoice_number_exact': 'Invoice number',
    'bank_signal_payment_reference_exact': 'Payment reference',
    'bank_signal_partner_account_exact': 'Partner account',
    'bank_signal_partner_name_normalized': 'Partner name',
    'bank_signal_due_date_proximity': 'Due date proximity',
    'bank_signal_booking_date_proximity': 'Booking date proximity',
    'bank_signal_currency_exact': 'Same currency',
    'bank_signal_open_amount_compatible': 'Compatible open amount',
    'bank_blocking_currency_mismatch': 'Currency mismatch',
    'bank_blocking_invoice_closed': 'Invoice is closed',
    'bank_blocking_invoice_conflict_requires_review': 'Invoice requires sync review',
    'bank_blocking_bank_transaction_ignored': 'Bank line is ignored',
    'bank_blocking_bank_transaction_already_posted': 'Bank line already posted',
    'bank_blocking_invalid_direction': 'Invalid direction',
    'bank_blocking_missing_open_amount': 'Missing open amount',
    'bank_blocking_duplicate_candidate': 'Duplicate candidate',
    'help_info_tooltip': 'Explanation',
    'help_info_close': 'Close',
    'help_term_open_amount_title': 'Open amount',
    'help_term_open_amount_body':
        'The part of the invoice not yet paid. When you confirm a match, this amount is reduced by the allocated payment.',
    'help_term_unallocated_title': 'Unallocated amount',
    'help_term_unallocated_body':
        'The part of the bank line not yet linked to invoices. It stays unassigned until you allocate it on confirm.',
    'help_term_partially_reconciled_title': 'Partially reconciled',
    'help_term_partially_reconciled_body':
        'The bank line is partly linked to invoices — some of the amount is allocated, some is not yet.',
    'help_term_match_confidence_title': 'Suggestion confidence',
    'help_term_match_confidence_body':
        'How strongly Operonix believes the bank line matches that invoice, based on amount, counterparty and reference. '
        'High confidence does not replace your review.',
    'help_term_cash_flow_category_title': 'Cash Flow category',
    'help_term_cash_flow_category_body':
        'Classifies cash as operating, investing or financing — required when confirming a match for cash reporting.',
    'help_cash_flow_tab_title': 'Cash Flow tab — overview',
    'help_cash_flow_tab_body':
        'Operational cash in Operonix: accounts, Cash Flow categories, manual transactions, '
        'planned items and forecast. ERP bank lines are matched to invoices and posted through '
        'confirmation. All writes go through the secure backend; the app does not recalculate '
        'canonical invoice amounts locally.\n\n'
        'Clerk (accounting_clerk) mainly drafts and views; accounting manager, admin and '
        'super_admin approve, post, reconcile bank lines and cancel confirmations.',
    'help_card_accounts_title': 'Accounts and cash registers',
    'help_card_accounts_body':
        'Master data for cash locations: bank accounts, FX accounts, registers. Balances are '
        'maintained by the backend from posted transactions. An account must exist before posting '
        'or bank confirmation.',
    'help_card_categories_title': 'Cash Flow categories',
    'help_card_categories_body':
        'Categories classify each cash movement as operating, investing or financing activity. '
        'Required when creating a transaction or confirming a bank line.',
    'help_card_transactions_title': 'Transactions',
    'help_card_transactions_body':
        'Manual operational cash: draft → post → reconcile or reverse. Allocate to invoices from '
        'a posted transaction. This is not the same as an ERP bank line — bank has its own import '
        'and match confirmation flow.',
    'help_card_realized_title': 'Realized Cash Flow',
    'help_card_realized_body':
        'Summary of posted and reconciled transactions for the selected period — inflows and '
        'outflows by account, category and direction.',
    'help_card_planned_items_title': 'Planned items',
    'help_card_planned_items_body':
        'Expected future inflows and outflows. Drafts must be approved before they affect forecast. '
        'Does not replace actual bank statements.',
    'help_card_forecast_title': 'Cash Flow forecast',
    'help_card_forecast_body':
        'Projection based on planned items and known balances — operational liquidity view, not an ERP report.',
    'help_card_bank_statements_title': 'Bank statement lines',
    'help_card_bank_statements_body':
        'Lines imported from ERP. Typical flow:\n'
        '1) Run import (ERP connection + bank account).\n'
        '2) Review list and filters.\n'
        '3) Generate match suggestions — inflow → sales invoices, outflow → purchase.\n'
        '4) Manually confirm amounts per invoice (partial or full).\n'
        '5) Review confirmation history; cancel if needed (reversal, no delete).\n\n'
        'Clerk can view; import, ignore and confirm require manager/admin/super_admin.',
    'help_invoices_tab_title': 'Invoices and open items tab',
    'help_invoices_tab_body':
        'Operational invoices and open receivables/payables within the tenant. May come from ERP sync '
        'or manual drafts. Open amounts feed payment allocation and bank matching.',
    'help_card_sales_invoices_title': 'Sales invoices',
    'help_card_sales_invoices_body':
        'Customer invoices: draft, issue, cancel. Open amount decreases via allocations and bank '
        'confirmation. Sync conflict status blocks automatic suggestions until resolved in ERP.',
    'help_card_purchase_invoices_title': 'Purchase invoices',
    'help_card_purchase_invoices_body':
        'Supplier invoices: draft, approve, cancel. Used when matching outflows and manual payment allocation.',
    'help_card_receivables_title': 'Receivables',
    'help_card_receivables_body':
        'Open sales invoices by customer — due dates, overdue and totals.',
    'help_card_payables_title': 'Payables',
    'help_card_payables_body':
        'Open purchase invoices by supplier — what is due and how much.',
    'help_erp_tab_title': 'ERP integration tab',
    'help_erp_tab_body':
        'Connect Operonix Finance to your accounting system. Credentials stay on the server; the app '
        'does not write bank files back to ERP. Sync jobs pull invoices and bank lines; mappings align fields.',
    'help_erp_connections_title': 'Active ERP connections',
    'help_erp_connections_body':
        'Configured connectors per company. New connections require manager/admin rights. '
        'Without a connection, bank import and invoice sync will not run.',
    'help_erp_bank_tile_title': 'Bank lines (from ERP tab)',
    'help_erp_bank_tile_body':
        'Same screen as in the Cash Flow tab — quick entry after setup. Import from the cloud icon on the list.',
    'help_erp_integration_dashboard_title': 'Integration dashboard',
    'help_erp_integration_dashboard_body':
        'Connector health, recent sync runs and integration summary.',
    'help_erp_document_links_title': 'Document links',
    'help_erp_document_links_body':
        'Operonix entities mapped to ERP records for traceability.',
    'help_erp_control_snapshots_title': 'Control snapshots',
    'help_erp_control_snapshots_body':
        'Snapshots for reconciling controlling data between Operonix and ERP.',
    'help_erp_error_resolution_title': 'Sync error resolution',
    'help_erp_error_resolution_body':
        'Retry or cancel failed sync jobs — first step when import returns nothing unexpected.',
    'help_erp_sync_jobs_title': 'Sync jobs',
    'help_erp_sync_jobs_body':
        'Scheduled and manual sync jobs — status, duration and type (invoices, bank, …).',
    'help_erp_sync_logs_title': 'Sync logs',
    'help_erp_sync_logs_body':
        'Detailed job logs for support and audit.',
    'help_erp_mappings_title': 'Mappings',
    'help_erp_mappings_body':
        'Rules for ERP fields becoming Operonix finance documents. Change only with business impact in mind.',
    'help_erp_csv_export_title': 'CSV / Excel export',
    'help_erp_csv_export_body':
        'Connections that support CSV/Excel export for manual checks.',
    'help_bank_list_title': 'Bank line list',
    'help_bank_list_body':
        'Imported bank statement lines. Period filter is client-side on booking date. Cloud icon runs import. '
        'Tap a line for detail, suggestions and confirmation history.',
    'help_bank_import_title': 'Bank statement import',
    'help_bank_import_body':
        'Pull new lines from ERP for the selected connection and bank account. Refresh the list after import. '
        'Manager/admin/super_admin only.',
    'help_bank_detail_title': 'Bank line detail',
    'help_bank_detail_body':
        'Line details (amount, direction, counterparty, references). Ignore only while not posted '
        'or reconciled (imported, unmatched, suggested, confirmed). Posted/reconciled lines cannot '
        'be ignored — cancel the confirmation in history to undo a match. Generate suggestions after '
        'import. Blocked suggestions cannot be confirmed.',
    'help_bank_suggestions_title': 'Match suggestions',
    'help_bank_suggestions_body':
        'Automatic candidates with score, confidence and business signals. Inflow → sales only; outflow → purchase only. '
        'Dismiss bad matches. Continue to confirmation does not auto-fill amounts.\n\n'
        'Suggestions with blocking reasons cannot be confirmed — reasons are listed on the suggestion card.',
    'help_bank_confirm_title': 'Confirm match',
    'help_bank_confirm_body':
        'Set amount per invoice, Cash Flow category and note. Preview shows bank amount, allocated and unallocated. '
        'Partial → partially_reconciled; full → reconciled. Same requestId on retry does not duplicate.',
    'help_bank_confirmation_title': 'Confirmation history',
    'help_bank_confirmation_body':
        'Who confirmed, Cash Flow transaction, invoice allocations and reconciliation status. '
        'Cancel (manager+) creates reversal and restores invoice open amounts — no delete.',
    'help_bank_audit_trail_title': 'History and audit trail',
    'help_bank_audit_trail_body':
        'IATF trail of all business-relevant events for this bank line — loaded from finance_audit_logs on every open. '
        'Shows who, when, what changed (before/after), reason and related entities. Records are append-only.',
    'finance_assistant_title': 'Finance assistant',
    'finance_assistant_module': 'Finance & Controlling',
    'finance_assistant_fab_title': 'Ask Finance assistant',
    'finance_assistant_fab_subtitle':
        'Explains screens, terms, and next steps across the Finance module.',
    'finance_assistant_current_screen': 'Currently explaining: {screen}',
    'finance_assistant_new_chat': 'New conversation',
    'finance_assistant_input_hint': 'Ask a question…',
    'finance_assistant_ask_more': 'Ask Finance assistant more about this',
    'finance_assistant_ctx_status': 'Line status: {status}',
    'finance_assistant_ctx_actions': 'Available actions: {actions}',
    'finance_assistant_screen_bank_statements_list': 'Bank statement lines',
    'finance_assistant_screen_bank_statement_detail': 'Bank line detail',
    'finance_assistant_screen_bank_match_confirm': 'Confirm match',
    'finance_assistant_screen_bank_match_confirmation_detail': 'Confirmation detail',
    'finance_assistant_screen_bank_match_suggestion_detail': 'Match suggestion detail',
    'finance_assistant_context_changed':
        'You are now on the {screen} screen. I can explain this area, available actions, and next steps.',
    'finance_assistant_q_what_is_screen': 'What is this screen for?',
    'finance_assistant_q_next_step': 'What is my next step?',
    'finance_assistant_a_what_is_screen':
        'You are on the {screen} screen within Finance & Controlling. I explain this area, available actions, and allowed steps — I do not execute actions for you.',
    'finance_assistant_a_next_step':
        'Check available actions and item status. Use entry, posting, or reconciliation actions allowed for your role.',
    'finance_assistant_intro_default':
        'The Finance assistant explains the current screen, terms, and allowed steps. Ask a question or pick a suggestion.',
    'finance_ai_analysis_title': 'Finance AI analysis',
    'finance_ai_analysis_tooltip': 'Finance AI analysis — insights and alerts',
    'finance_assistant_tab_overview': 'Overview',
    'finance_assistant_tab_production': 'Production',
    'finance_assistant_tab_downtime': 'Downtime',
    'finance_assistant_tab_quality': 'Quality',
    'finance_assistant_tab_maintenance': 'Maintenance',
    'finance_assistant_tab_procurement': 'Procurement',
    'finance_assistant_tab_budgets': 'Budgets',
    'finance_assistant_tab_invoices': 'Invoices and open items',
    'finance_assistant_tab_erp': 'ERP',
    'finance_assistant_screen_finance_controlling_dashboard': 'Controlling overview',
    'finance_assistant_screen_finance_controlling_production': 'Controlling — production',
    'finance_assistant_screen_finance_controlling_downtime': 'Controlling — downtime',
    'finance_assistant_screen_finance_controlling_quality': 'Controlling — quality',
    'finance_assistant_screen_finance_controlling_maintenance': 'Controlling — maintenance',
    'finance_assistant_screen_finance_controlling_procurement': 'Controlling — procurement',
    'finance_assistant_screen_finance_budgets': 'Budgets',
    'finance_assistant_screen_finance_cash_flow_hub': 'Cash Flow',
    'finance_assistant_screen_finance_invoices_hub': 'Invoices and open items',
    'finance_assistant_screen_finance_erp_hub': 'ERP integrations',
    'finance_assistant_screen_finance_erp_integrations_only': 'ERP integrations',
    'finance_assistant_screen_finance_accounts_list': 'Accounts and cash desks',
    'finance_assistant_screen_finance_account_form': 'Account entry',
    'finance_assistant_screen_finance_cash_flow_categories_list': 'Cash Flow categories',
    'finance_assistant_screen_finance_cash_flow_category_form': 'Category entry',
    'finance_assistant_screen_finance_transactions_list': 'Transactions',
    'finance_assistant_screen_finance_transaction_detail': 'Transaction detail',
    'finance_assistant_screen_finance_transaction_form': 'Transaction entry',
    'finance_assistant_screen_finance_realized_cash_flow': 'Realized Cash Flow',
    'finance_assistant_screen_finance_planned_cash_items_list': 'Planned items',
    'finance_assistant_screen_finance_planned_item_detail': 'Planned item detail',
    'finance_assistant_screen_finance_planned_item_form': 'Planned item entry',
    'finance_assistant_screen_finance_cash_flow_forecast': 'Cash Flow forecast',
    'finance_assistant_screen_finance_budget_vs_actual':
        'Budget vs actual and working capital',
    'finance_assistant_screen_finance_dso_dpo_ccc': 'DSO / DPO / CCC',
    'finance_assistant_screen_finance_sales_invoice_detail': 'Sales invoice detail',
    'finance_assistant_screen_finance_sales_invoice_form': 'Sales invoice entry',
    'finance_assistant_screen_finance_purchase_invoices_list': 'Purchase invoices',
    'finance_assistant_screen_finance_purchase_invoice_detail': 'Purchase invoice detail',
    'finance_assistant_screen_finance_purchase_invoice_form': 'Purchase invoice entry',
    'finance_assistant_screen_finance_receivables_list': 'Receivables',
    'finance_assistant_screen_finance_payables_list': 'Payables',
    'finance_assistant_screen_finance_allocate_payment': 'Payment allocation',
    'finance_assistant_screen_finance_payment_allocation_detail': 'Allocation detail',
    'finance_assistant_screen_finance_ai_assistant': 'Finance AI analysis',
    'finance_assistant_screen_finance_ai_alert_detail': 'Finance AI alert',
    'finance_assistant_screen_finance_ai_notification_delivery_detail': 'Finance AI notification',
    'finance_assistant_offline_fallback':
        'Operonix Industrial Finance assistant is currently offline. A basic explanation of this screen is shown.',
    'finance_assistant_intro_bank_statements_list':
        'I am here to explain this screen and help you link bank inflows or outflows to invoices. '
        'I will not post or confirm anything for you.',
    'finance_assistant_intro_bank_statement_detail':
        'On the line detail you see suggestions, confirmation history and the audit trail. '
        'I guide the next step — no automatic posting.',
    'finance_assistant_intro_bank_match_confirm':
        'Here you set allocations before posting. Review amounts before confirming.',
    'finance_assistant_intro_bank_match_confirmation_detail':
        'This is the audit record of a confirmation or cancellation. I can explain reversal and allocations.',
    'finance_assistant_intro_bank_match_suggestion_detail':
        'The suggestion ranks invoices by amount, reference and partner. Review blocking reasons before confirming.',
    'finance_assistant_q_bank_list_purpose': 'What is this screen for?',
    'finance_assistant_q_bank_generate': 'What does Generate suggestions mean?',
    'finance_assistant_q_bank_why_suggested': 'Why was this invoice suggested?',
    'finance_assistant_q_bank_confirm_effect': 'What happens if I confirm?',
    'finance_assistant_q_bank_cancel_effect': 'What does cancelling a confirmation mean?',
    'finance_assistant_q_bank_next_step': 'What is my next step?',
    'finance_assistant_q_scenario_base_vs_pessimistic':
        'What is the difference between base and pessimistic scenario?',
    'finance_assistant_q_scenario_types':
        'What are base, optimistic and pessimistic scenarios?',
    'finance_assistant_q_scenario_approve': 'What does approving a scenario mean?',
    'finance_assistant_q_bawc_budget_vs_actual_period':
        'Explain budget vs actual for this period.',
    'finance_assistant_q_bawc_outflow_above_plan':
        'Why is actual outflow higher than plan?',
    'finance_assistant_q_bawc_unfavorable_variance':
        'What does unfavourable variance mean?',
    'finance_assistant_q_bawc_variance_not_applicable':
        'Why is variance percent not applicable?',
    'finance_assistant_q_bawc_net_cash_flow':
        'Explain net cash flow for this period.',
    'finance_assistant_q_wc_dso_period_vs_average':
        'What is the difference between period-end DSO and average collection days?',
    'finance_assistant_q_wc_is_dso_good': 'Is 29 days DSO good or bad?',
    'finance_assistant_q_wc_dio_ccc_unavailable': 'Why are DIO and CCC unavailable?',
    'finance_assistant_q_wc_dpo_cash_impact': 'How does DPO affect cash flow?',
    'finance_assistant_q_wc_meaning_dso': 'What does DSO mean?',
    'finance_assistant_q_wc_meaning_dpo': 'What does DPO mean?',
    'finance_assistant_q_wc_meaning_dio': 'What does DIO mean?',
    'finance_assistant_q_wc_meaning_ccc': 'What does CCC mean?',
    'finance_assistant_q_wc_metrics_overview': 'Explain working capital metrics.',
    'finance_assistant_intro_budget_vs_actual':
        'I explain approved budget versus posted cash flow transactions and DSO/DPO metrics. '
        'Currencies are EUR and BAM only. I do not post or change data for you.',
    'finance_assistant_intro_dso_dpo_ccc':
        'I explain periodic DSO/DPO and average actual collection/payment days. '
        'DIO and CCC await inventory and COGS integration.',
    'finance_assistant_a_bank_list_purpose':
        'What it means: imported bank lines that should be matched to invoices.\n\n'
        'What to do: filter the period, open a line or run import.\n\n'
        'What happens: import pulls new lines from ERP; matching continues on the detail screen.',
    'finance_assistant_a_bank_generate':
        'What it means: Operonix searches invoices matching amount, reference and partner.\n\n'
        'What to do: on the line detail tap Generate suggestions.\n\n'
        'What happens: you get ranked candidates; you choose which goes to confirmation.',
    'finance_assistant_a_bank_why_suggested':
        'What it means: the suggestion uses signals such as amount, invoice number and payment reference.\n\n'
        'What to do: open the suggestion and check blocking reasons (e.g. currency).\n\n'
        'What happens: dismiss a bad match; proceed with a good one to Confirm.',
    'finance_assistant_a_bank_confirm_effect':
        'What it means: confirmation posts a Cash Flow transaction and allocations to invoices.\n\n'
        'What to do: review amounts, category and note, then Confirm.\n\n'
        'What happens: the bank line becomes partially or fully reconciled; the trail is kept.',
    'finance_assistant_a_bank_cancel_effect':
        'What it means: cancellation creates a reversal and restores open invoice amounts.\n\n'
        'What to do: enter a business reason for cancellation.\n\n'
        'What happens: confirmation becomes cancelled; the full chain stays visible in history.',
    'finance_assistant_a_bank_next_step':
        'What to do: follow the line status — import → suggestions → confirm → reconcile.\n\n'
        'If an action is unavailable, check your role and blocking reasons on the suggestion.',
    'finance_assistant_a_scenario_base_vs_pessimistic':
        'What it means: the base scenario starts from the Cash Flow forecast and planned items; '
        'the pessimistic one simulates delayed collection and higher outflows.\n\n'
        'What to do: compare both scenarios or open comparison in Advanced Cash Flow analysis.\n\n'
        'What happens: differences appear by period; an approved scenario does not change transactions.',
    'finance_assistant_a_scenario_types':
        'What it means: base (reference plan), optimistic (faster collection), '
        'pessimistic (delays and higher outflows) and What-if (parameter simulation).\n\n'
        'What to do: create a new scenario in Advanced Cash Flow analysis.',
    'finance_assistant_a_scenario_approve':
        'What it means: approval means the scenario is accepted for liquidity planning — it does not post transactions.\n\n'
        'What to do: after calculation review assumptions and tap Approve on scenario detail.',
    'finance_assistant_a_bawc_budget_vs_actual_period':
        'Budget vs actual compares the approved plan with posted cash flow transactions '
        'for the same period, currency and plant scope.',
    'finance_assistant_a_bawc_outflow_above_plan':
        'What it means: actual outflow is the sum of posted and reconciled cash outflows; '
        'plan comes from the approved budget for the same period, currency and plant scope.\n\n'
        'What to do: compare planned and actual outflow on the Budget vs actual card.',
    'finance_assistant_a_bawc_unfavorable_variance':
        'What it means: unfavourable variance means lower inflow, higher outflow or weaker net cash flow versus plan.\n\n'
        'What to do: review variance for inflow, outflow and net cash flow.',
    'finance_assistant_a_bawc_variance_not_applicable':
        'What it means: when plan is zero, variance percent is meaningless — the UI shows “Not applicable”.\n\n'
        'What to do: check whether an approved budget exists; focus on absolute variance.',
    'finance_assistant_a_bawc_net_cash_flow':
        'What it means: net cash flow = actual inflow minus actual outflow; planned net = planned inflow minus planned outflow.\n\n'
        'What to do: compare planned and actual net on the card.',
    'finance_assistant_a_wc_dso_period_vs_average':
        'What it means: period-end DSO uses open receivables and credit sales; '
        'average collection days use actual days to confirmed payment for paid invoices.\n\n'
        'What to do: compare both values in Working capital.',
    'finance_assistant_a_wc_is_dso_good':
        'What it means: DSO has no universal “good” number — it depends on industry and payment terms.\n\n'
        'What to do: compare DSO over time and to your internal collection target.',
    'finance_assistant_a_wc_dio_ccc_unavailable':
        'What it means: DIO requires average inventory and canonical COGS; '
        'CCC is not available without DIO and must not be estimated as DSO minus DPO alone.\n\n'
        'What to do: use available DSO and DPO metrics; DIO/CCC come after ERP/warehouse integration.',
    'finance_assistant_a_wc_dpo_cash_impact':
        'What it means: longer DPO usually keeps cash in the company longer; shorter DPO means earlier payments.\n\n'
        'What to do: compare both DPO metrics with net cash flow in Working capital.',
    'finance_assistant_a_wc_meaning_dso':
        'DSO — Days Sales Outstanding shows for how many days receivables from customers are collected on average. '
        'Simply: how long cash stays with customers before it reaches your account.',
    'finance_assistant_a_wc_meaning_dpo':
        'DPO — Days Payable Outstanding shows for how many days you pay suppliers on average. '
        'Simply: how long the company keeps cash before paying obligations.',
    'finance_assistant_a_wc_meaning_dio':
        'DIO — Days Inventory Outstanding shows how many days capital is tied up in inventory. '
        'Reliable inventory and cost-of-goods-sold data are required.',
    'finance_assistant_a_wc_meaning_ccc':
        'CCC — Cash Conversion Cycle shows how many days cash stays tied up in the business cycle. '
        'It is calculated only when DIO, DSO and DPO are all available: CCC = DIO + DSO − DPO.',
    'finance_assistant_a_wc_metrics_overview':
        'Working capital metrics: DSO (customer collection), DPO (supplier payment), '
        'DIO (inventory) and CCC (full cash cycle). DIO and CCC show as not available until ERP/warehouse integration.',
    'finance_assistant_a_free_text':
        'For detailed questions use the suggested chips or contact your administrator. '
        'I explain flow and terms — I do not post on your behalf.',
    'finance_assistant_a_default':
        'Pick a suggested question or describe what is unclear on this screen.',
    'help_finance_hub_tabs_title': 'Finance & Controlling — tabs',
    'help_finance_hub_tabs_body':
        'Top tabs split the module:\n'
        '• Overview — KPI and controlling cards for the selected period.\n'
        '• Production, Downtime, Quality, Maintenance, Procurement — cost and operational aggregates.\n'
        '• Budgets — plan vs. actual for the business year.\n'
        '• Cash Flow — operational cash, accounts, transactions, bank lines (ⓘ on each card).\n'
        '• Invoices and open items — sales/purchase invoices, receivables and payables.\n'
        '• ERP — accounting connection, sync and bank import.\n\n'
        'Tap ⓘ on any hub card for details without opening the screen.',
  };
}
