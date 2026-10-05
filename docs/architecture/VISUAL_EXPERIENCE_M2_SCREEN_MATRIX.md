# VISUAL-EXPERIENCE-M2 — Production screen matrix

Every reachable `*_screen.dart` surface. Dialogs, sheets and date fields that are not separate screens use the shared Premium dialog, sheet, table and calendar theme.

`MaterialApp` already selects `OperonixVisualTheme.premiumMidnight()` or `classic()`. M1 screens keep their approved composition. Every other screen keeps the same business tree and receives Premium surfaces, filled fields, borderless cards, dialog and sheet radius, the table header band and the calendar theme.

| Screen | Area | Type | Classic | Premium | Composition |
| --- | --- | --- | --- | --- | --- |
| `catalog_evidence_station_screen.dart` | catalog_evidence_runtime | SHOP-FLOOR | supported | supported | shared Premium theme |
| `process_evidence_analytics_screen.dart` | process_evidence_analytics | REPORT | supported | supported | shared Premium theme |
| `final_control_work_screen.dart` | profile_driven_structured_runtime | SHOP-FLOOR | supported | supported | shared Premium theme |
| `structured_profile_driven_work_screen.dart` | profile_driven_structured_runtime | MASTER DATA | supported | supported | shared Premium theme |
| `evidence_payload_scan_screen.dart` | widgets | MASTER DATA | supported | supported | shared Premium theme |
| `profile_driven_evidence_detail_screen.dart` | station_evidence | DETAIL | supported | supported | shared Premium theme |
| `profile_driven_evidence_list_screen.dart` | station_evidence | LIST | supported | supported | shared Premium theme |
| `profile_driven_evidence_records_screen.dart` | station_evidence | MASTER DATA | supported | supported | shared Premium theme |
| `production_station_terminal_root_screen.dart` | station_terminal | SHOP-FLOOR | supported | supported | shared Premium theme |
| `worker_performance_ai_planning_screen.dart` | worker_ai_planning | MASTER DATA | supported | supported | shared Premium theme |
| `workforce_performance_norm_detail_screen.dart` | workforce_performance_norms | DETAIL | supported | supported | shared Premium theme |
| `workforce_performance_norms_list_screen.dart` | workforce_performance_norms | LIST | supported | supported | shared Premium theme |
| `pending_users_screen.dart` | register | MASTER DATA | supported | supported | shared Premium theme |
| `register_screen.dart` | register | MASTER DATA | supported | supported | shared Premium theme |
| `login_screen.dart` | auth | MASTER DATA | supported | supported | shared Premium theme |
| `station_device_mode_screen.dart` | auth | SHOP-FLOOR | supported | supported | shared Premium theme |
| `unified_assessment_run_screen.dart` | assessment | MASTER DATA | supported | supported | shared Premium theme |
| `document_pdf_settings_screen.dart` | orders | SETTINGS | supported | supported | shared Premium theme |
| `order_create_screen.dart` | orders | FORM | supported | supported | shared Premium theme |
| `order_details_screen.dart` | orders | DETAIL | supported | supported | shared Premium theme |
| `order_edit_screen.dart` | orders | FORM | supported | supported | shared Premium theme |
| `order_line_production_create_screen.dart` | orders | FORM | supported | supported | shared Premium theme |
| `orders_list_screen.dart` | orders | LIST | supported | supported | shared Premium theme |
| `activity_sector_settings_screen.dart` | partners | SETTINGS | supported | supported | shared Premium theme |
| `activity_sectors_catalog_screen.dart` | partners | MASTER DATA | supported | supported | shared Premium theme |
| `partner_customer_edit_screen.dart` | partners | FORM | supported | supported | shared Premium theme |
| `partner_customer_requirements_profile_screen.dart` | partners | MASTER DATA | supported | supported | shared Premium theme |
| `partner_supplier_edit_screen.dart` | partners | FORM | supported | supported | shared Premium theme |
| `partners_screen.dart` | partners | MASTER DATA | supported | supported | shared Premium theme |
| `supplier_evaluations_screen.dart` | partners | MASTER DATA | supported | supported | shared Premium theme |
| `supplier_selection_screen.dart` | partners | MASTER DATA | supported | supported | shared Premium theme |
| `development_portfolio_supplier_detail_screen.dart` | development | DETAIL | supported | supported | shared Premium theme |
| `development_project_create_screen.dart` | development | FORM | supported | supported | shared Premium theme |
| `development_project_demo_fullscreen_screen.dart` | development | MASTER DATA | supported | supported | shared Premium theme |
| `development_project_details_screen.dart` | development | DETAIL | supported | supported | shared Premium theme |
| `development_project_edit_screen.dart` | development | FORM | supported | supported | shared Premium theme |
| `development_project_team_screen.dart` | development | MASTER DATA | supported | supported | shared Premium theme |
| `development_projects_list_screen.dart` | development | LIST | supported | supported | shared Premium theme |
| `finance_account_form_screen.dart` | accounts | FORM | supported | supported | shared Premium theme |
| `finance_accounts_screen.dart` | accounts | MASTER DATA | supported | supported | shared Premium theme |
| `finance_advanced_cash_flow_screen.dart` | advanced_cash_flow | MASTER DATA | supported | supported | shared Premium theme |
| `finance_budget_actual_working_capital_screen.dart` | advanced_cash_flow | MASTER DATA | supported | supported | shared Premium theme |
| `finance_scenario_comparison_screen.dart` | advanced_cash_flow | MASTER DATA | supported | supported | shared Premium theme |
| `finance_scenario_detail_screen.dart` | advanced_cash_flow | DETAIL | supported | supported | shared Premium theme |
| `finance_scenario_form_screen.dart` | advanced_cash_flow | FORM | supported | supported | shared Premium theme |
| `finance_ai_alert_detail_screen.dart` | ai_advisory | DETAIL | supported | supported | shared Premium theme |
| `finance_ai_recommendation_kpi_screen.dart` | ai_kpi | MASTER DATA | supported | supported | shared Premium theme |
| `finance_ai_notification_delivery_detail_screen.dart` | ai_notifications | DETAIL | supported | supported | shared Premium theme |
| `finance_ai_notification_inbox_screen.dart` | ai_notifications | MASTER DATA | supported | supported | shared Premium theme |
| `finance_bank_match_confirm_screen.dart` | bank_reconciliation | MASTER DATA | supported | supported | shared Premium theme |
| `finance_bank_match_confirmation_detail_screen.dart` | bank_reconciliation | DETAIL | supported | supported | shared Premium theme |
| `finance_bank_statement_detail_screen.dart` | bank_reconciliation | DETAIL | supported | supported | shared Premium theme |
| `finance_bank_statements_screen.dart` | bank_reconciliation | MASTER DATA | supported | supported | shared Premium theme |
| `finance_cash_flow_categories_screen.dart` | cash_flow_categories | MASTER DATA | supported | supported | shared Premium theme |
| `finance_cash_flow_category_form_screen.dart` | cash_flow_categories | FORM | supported | supported | shared Premium theme |
| `finance_cash_transaction_detail_screen.dart` | cash_transactions | DETAIL | supported | supported | shared Premium theme |
| `finance_cash_transaction_form_screen.dart` | cash_transactions | FORM | supported | supported | shared Premium theme |
| `finance_cash_transactions_screen.dart` | cash_transactions | MASTER DATA | supported | supported | shared Premium theme |
| `finance_realized_cash_flow_screen.dart` | cash_transactions | MASTER DATA | supported | supported | shared Premium theme |
| `finance_cash_flow_forecast_screen.dart` | forecast | MASTER DATA | supported | supported | shared Premium theme |
| `finance_purchase_invoice_detail_screen.dart` | invoices | DETAIL | supported | supported | shared Premium theme |
| `finance_purchase_invoice_form_screen.dart` | invoices | FORM | supported | supported | shared Premium theme |
| `finance_purchase_invoices_screen.dart` | invoices | MASTER DATA | supported | supported | shared Premium theme |
| `finance_sales_invoice_detail_screen.dart` | invoices | DETAIL | supported | supported | shared Premium theme |
| `finance_sales_invoice_form_screen.dart` | invoices | FORM | supported | supported | shared Premium theme |
| `finance_sales_invoices_screen.dart` | invoices | MASTER DATA | supported | supported | shared Premium theme |
| `finance_payables_screen.dart` | payables | MASTER DATA | supported | supported | shared Premium theme |
| `finance_allocate_payment_screen.dart` | payment_allocations | MASTER DATA | supported | supported | shared Premium theme |
| `finance_payment_allocation_detail_screen.dart` | payment_allocations | DETAIL | supported | supported | shared Premium theme |
| `finance_planned_cash_item_detail_screen.dart` | planned_cash_items | DETAIL | supported | supported | shared Premium theme |
| `finance_planned_cash_item_form_screen.dart` | planned_cash_items | FORM | supported | supported | shared Premium theme |
| `finance_planned_cash_items_screen.dart` | planned_cash_items | MASTER DATA | supported | supported | shared Premium theme |
| `finance_receivables_screen.dart` | receivables | MASTER DATA | supported | supported | shared Premium theme |
| `finance_ai_assistant_screen.dart` | finance_integrations | MASTER DATA | supported | supported | shared Premium theme |
| `finance_connection_edit_screen.dart` | finance_integrations | FORM | supported | supported | shared Premium theme |
| `finance_connections_screen.dart` | finance_integrations | MASTER DATA | supported | supported | shared Premium theme |
| `finance_control_dashboard_screen.dart` | finance_integrations | HOME / DASHBOARD | supported | supported | shared Premium theme |
| `finance_controlling_hub_screen.dart` | finance_integrations | LIST | supported | supported | shared Premium theme |
| `finance_csv_export_capabilities_screen.dart` | finance_integrations | MASTER DATA | supported | supported | shared Premium theme |
| `finance_document_links_screen.dart` | finance_integrations | MASTER DATA | supported | supported | shared Premium theme |
| `finance_error_resolution_screen.dart` | finance_integrations | MASTER DATA | supported | supported | shared Premium theme |
| `finance_integration_dashboard_screen.dart` | finance_integrations | HOME / DASHBOARD | supported | supported | shared Premium theme |
| `finance_integration_hub_screen.dart` | finance_integrations | LIST | supported | supported | shared Premium theme |
| `finance_mapping_rules_screen.dart` | finance_integrations | MASTER DATA | supported | supported | shared Premium theme |
| `finance_placeholder_screen.dart` | finance_integrations | MASTER DATA | supported | supported | shared Premium theme |
| `finance_sync_jobs_screen.dart` | finance_integrations | MASTER DATA | supported | supported | shared Premium theme |
| `finance_sync_logs_screen.dart` | finance_integrations | MASTER DATA | supported | supported | shared Premium theme |
| `inventory_adjustments_screen.dart` | adjustments | MASTER DATA | supported | supported | shared Premium theme |
| `internal_supply_module_screen.dart` | internal_supply | MASTER DATA | supported | supported | shared Premium theme |
| `internal_supply_order_detail_screen.dart` | internal_supply | DETAIL | supported | supported | shared Premium theme |
| `logistics_receipt_qr_result_screen.dart` | receipt | MASTER DATA | supported | supported | shared Premium theme |
| `packing_box_receipt_screen.dart` | receipt | SHOP-FLOOR | supported | supported | shared Premium theme |
| `production_label_receipt_screen.dart` | receipt | MASTER DATA | supported | supported | shared Premium theme |
| `station1_packed_boxes_logistics_screen.dart` | receipt | SHOP-FLOOR | supported | supported | shared Premium theme |
| `warehouse_routes_screen.dart` | routes | MASTER DATA | supported | supported | shared Premium theme |
| `logistics_hub_entry_screen.dart` | logistics | LIST | supported | supported | shared Premium theme |
| `warehouse_hub_screen.dart` | warehouse_hub | LIST | supported | supported | shared Premium theme |
| `warehouse_wms_dashboard_screen.dart` | wms | HOME / DASHBOARD | supported | supported | shared Premium theme |
| `wms_lot_scan_result_screen.dart` | wms | MASTER DATA | supported | supported | shared Premium theme |
| `wms_picking_screen.dart` | wms | MASTER DATA | supported | supported | shared Premium theme |
| `wms_putaway_screen.dart` | wms | MASTER DATA | supported | supported | shared Premium theme |
| `wms_quality_screen.dart` | wms | MASTER DATA | supported | supported | shared Premium theme |
| `wms_receipts_list_screen.dart` | wms | LIST | supported | supported | shared Premium theme |
| `wms_receiving_screen.dart` | wms | MASTER DATA | supported | supported | shared Premium theme |
| `wms_shipping_screen.dart` | wms | MASTER DATA | supported | supported | shared Premium theme |
| `work_time_attendance_workspace_screen.dart` | work_time | MASTER DATA | supported | supported | shared Premium theme |
| `work_time_audit_log_screen.dart` | work_time | MASTER DATA | supported | supported | shared Premium theme |
| `work_time_corrections_screen.dart` | work_time | MASTER DATA | supported | supported | shared Premium theme |
| `work_time_daily_screen.dart` | work_time | MASTER DATA | supported | supported | shared Premium theme |
| `work_time_devices_screen.dart` | work_time | MASTER DATA | supported | supported | shared Premium theme |
| `work_time_hr_ai_insights_screen.dart` | work_time | MASTER DATA | supported | supported | shared Premium theme |
| `work_time_hr_kpi_report_screen.dart` | work_time | REPORT | supported | supported | shared Premium theme |
| `work_time_hub_screen.dart` | work_time | LIST | supported | supported | shared Premium theme |
| `work_time_manager_assignment_screen.dart` | work_time | MASTER DATA | supported | supported | shared Premium theme |
| `work_time_monthly_screen.dart` | work_time | MASTER DATA | supported | supported | shared Premium theme |
| `work_time_overview_screen.dart` | work_time | MASTER DATA | supported | supported | shared Premium theme |
| `work_time_payroll_export_screen.dart` | work_time | MASTER DATA | supported | supported | shared Premium theme |
| `work_time_rules_screen.dart` | work_time | MASTER DATA | supported | supported | shared Premium theme |
| `work_time_worker_absences_screen.dart` | work_time | MASTER DATA | supported | supported | shared Premium theme |
| `aps_ai_execution_assistant_screen.dart` | aps | SHOP-FLOOR | supported | supported | shared Premium theme |
| `aps_capacity_screen.dart` | aps | MASTER DATA | supported | supported | shared Premium theme |
| `aps_debug_hub_screen.dart` | aps | LIST | supported | supported | shared Premium theme |
| `aps_gantt_read_only_screen.dart` | aps | REPORT | supported | supported | shared Premium theme |
| `aps_hub_screen.dart` | aps | LIST | supported | supported | shared Premium theme |
| `aps_optimization_screen.dart` | aps | MASTER DATA | supported | supported | shared Premium theme |
| `aps_p0_debug_screen.dart` | aps | MASTER DATA | supported | supported | shared Premium theme |
| `aps_p1_debug_screen.dart` | aps | MASTER DATA | supported | supported | shared Premium theme |
| `aps_p2_debug_screen.dart` | aps | MASTER DATA | supported | supported | shared Premium theme |
| `aps_scenarios_demands_screen.dart` | aps | MASTER DATA | supported | supported | shared Premium theme |
| `operonix_ai_feedback_signals_screen.dart` | ai | MASTER DATA | supported | supported | shared Premium theme |
| `operonix_ai_operational_briefing_screen.dart` | ai | MASTER DATA | supported | supported | shared Premium theme |
| `operonix_ai_watchlist_screen.dart` | ai | LIST | supported | supported | shared Premium theme |
| `production_ai_chat_screen.dart` | ai | MASTER DATA | supported | supported | shared Premium theme |
| `production_ai_hub_screen.dart` | ai | LIST | supported | supported | shared Premium theme |
| `production_tracking_assistant_screen.dart` | ai | SHOP-FLOOR | supported | supported | shared Premium theme |
| `ai_analysis_screen.dart` | ai_analysis | MASTER DATA | supported | supported | shared Premium theme |
| `analytics_work_center_details_screen.dart` | analytics | REPORT | supported | supported | shared Premium theme |
| `operonix_analytics_dashboard_screen.dart` | analytics | HOME / DASHBOARD | supported | supported | shared Premium theme |
| `production_dashboard_screen.dart` | dashboard | HOME / DASHBOARD | supported | supported | M1 composition preserved |
| `downtime_create_screen.dart` | downtime | FORM | supported | supported | shared Premium theme |
| `downtime_details_screen.dart` | downtime | DETAIL | supported | supported | shared Premium theme |
| `downtimes_screen.dart` | downtime | MASTER DATA | supported | supported | shared Premium theme |
| `process_execution_hub_screen.dart` | execution | SHOP-FLOOR | supported | supported | shared Premium theme |
| `production_execution_screen.dart` | execution | SHOP-FLOOR | supported | supported | shared Premium theme |
| `production_fault_asset_qr_scan_screen.dart` | issues | MASTER DATA | supported | supported | shared Premium theme |
| `production_fault_detail_screen.dart` | issues | DETAIL | supported | supported | shared Premium theme |
| `production_problem_reporting_screen.dart` | issues | REPORT | supported | supported | shared Premium theme |
| `mes_inbox_screen.dart` | notifications | MASTER DATA | supported | supported | shared Premium theme |
| `mes_notification_preferences_screen.dart` | notifications | MASTER DATA | supported | supported | shared Premium theme |
| `capacity_calendar_edit_screen.dart` | ooe | FORM | supported | supported | shared Premium theme |
| `capacity_overview_screen.dart` | ooe | MASTER DATA | supported | supported | shared Premium theme |
| `factory_performance_dashboard_screen.dart` | ooe | HOME / DASHBOARD | supported | supported | shared Premium theme |
| `ooe_alert_rules_screen.dart` | ooe | REPORT | supported | supported | shared Premium theme |
| `ooe_alerts_screen.dart` | ooe | REPORT | supported | supported | shared Premium theme |
| `ooe_daily_overview_screen.dart` | ooe | REPORT | supported | supported | shared Premium theme |
| `ooe_dashboard_screen.dart` | ooe | HOME / DASHBOARD | supported | supported | shared Premium theme |
| `ooe_loss_analysis_screen.dart` | ooe | REPORT | supported | supported | shared Premium theme |
| `ooe_loss_reasons_screen.dart` | ooe | REPORT | supported | supported | shared Premium theme |
| `ooe_machine_details_screen.dart` | ooe | REPORT | supported | supported | shared Premium theme |
| `ooe_machine_targets_screen.dart` | ooe | REPORT | supported | supported | shared Premium theme |
| `ooe_shift_context_screen.dart` | ooe | REPORT | supported | supported | shared Premium theme |
| `ooe_shift_summary_screen.dart` | ooe | REPORT | supported | supported | shared Premium theme |
| `scada_live_hub_screen.dart` | ooe | LIST | supported | supported | shared Premium theme |
| `teep_analysis_screen.dart` | ooe | MASTER DATA | supported | supported | shared Premium theme |
| `station1_close_box_screen.dart` | packing | SHOP-FLOOR | supported | supported | shared Premium theme |
| `production_capacity_overview_screen.dart` | planning | MASTER DATA | supported | supported | shared Premium theme |
| `production_plan_details_screen.dart` | planning | DETAIL | supported | supported | shared Premium theme |
| `production_plan_execution_screen.dart` | planning | SHOP-FLOOR | supported | supported | shared Premium theme |
| `production_plan_gantt_screen.dart` | planning | REPORT | supported | supported | shared Premium theme |
| `production_planning_home_screen.dart` | planning | HOME / DASHBOARD | supported | supported | shared Premium theme |
| `production_planning_hub_screen.dart` | planning | LIST | supported | supported | shared Premium theme |
| `production_planning_screen.dart` | planning | MASTER DATA | supported | supported | shared Premium theme |
| `production_plans_list_screen.dart` | planning | LIST | supported | supported | shared Premium theme |
| `production_process_create_screen.dart` | processes | FORM | supported | supported | shared Premium theme |
| `production_process_details_screen.dart` | processes | DETAIL | supported | supported | shared Premium theme |
| `production_process_edit_screen.dart` | processes | FORM | supported | supported | shared Premium theme |
| `production_processes_list_screen.dart` | processes | LIST | supported | supported | M1 composition preserved |
| `production_order_create_screen.dart` | production_orders | FORM | supported | supported | shared Premium theme |
| `production_order_details_screen.dart` | production_orders | DETAIL | supported | supported | shared Premium theme |
| `production_order_edit_screen.dart` | production_orders | FORM | supported | supported | shared Premium theme |
| `production_order_mes_assignment_screen.dart` | production_orders | MASTER DATA | supported | supported | shared Premium theme |
| `production_orders_list_screen.dart` | production_orders | LIST | supported | supported | M1 composition preserved |
| `product_create_screen.dart` | products | FORM | supported | supported | shared Premium theme |
| `product_details_screen.dart` | products | DETAIL | supported | supported | shared Premium theme |
| `product_edit_screen.dart` | products | FORM | supported | supported | shared Premium theme |
| `product_register_from_scan_screen.dart` | products | MASTER DATA | supported | supported | shared Premium theme |
| `products_list_screen.dart` | products | LIST | supported | supported | shared Premium theme |
| `production_qr_scan_screen.dart` | qr | MASTER DATA | supported | supported | shared Premium theme |
| `production_ai_report_screen.dart` | reports | REPORT | supported | supported | shared Premium theme |
| `station_tracking_setup_screen.dart` | station | SHOP-FLOOR | supported | supported | shared Premium theme |
| `production_company_evidence_admin_screen.dart` | station_pages | MASTER DATA | supported | supported | shared Premium theme |
| `production_evidence_catalog_screen.dart` | station_pages | MASTER DATA | supported | supported | shared Premium theme |
| `production_evidence_config_form_screen.dart` | station_pages | FORM | supported | supported | shared Premium theme |
| `production_evidence_operator_hub_screen.dart` | station_pages | LIST | supported | supported | M1 composition preserved |
| `production_evidence_operator_launch_screen.dart` | station_pages | MASTER DATA | supported | supported | shared Premium theme |
| `production_profile_station_launch_screen.dart` | station_pages | SHOP-FLOOR | supported | supported | shared Premium theme |
| `production_profile_stations_hub_screen.dart` | station_pages | SHOP-FLOOR | supported | supported | shared Premium theme |
| `production_station_admin_form_screen.dart` | station_pages | SHOP-FLOOR | supported | supported | shared Premium theme |
| `production_station_pages_admin_screen.dart` | station_pages | SHOP-FLOOR | supported | supported | shared Premium theme |
| `production_stations_admin_screen.dart` | station_pages | SHOP-FLOOR | supported | supported | shared Premium theme |
| `station1_operator_launch_screen.dart` | station_pages | SHOP-FLOOR | supported | supported | shared Premium theme |
| `station2_operator_launch_screen.dart` | station_pages | SHOP-FLOOR | supported | supported | shared Premium theme |
| `profile_driven_work_screen.dart` | station_work | MASTER DATA | supported | supported | shared Premium theme |
| `station1_work_screen.dart` | station_work | SHOP-FLOOR | supported | supported | shared Premium theme |
| `station2_work_screen.dart` | station_work | SHOP-FLOOR | supported | supported | shared Premium theme |
| `production_operator_tracking_day_report_screen.dart` | tracking | REPORT | supported | supported | shared Premium theme |
| `production_operator_tracking_screen.dart` | tracking | SHOP-FLOOR | supported | supported | M1 composition preserved |
| `production_operator_tracking_station_screen.dart` | tracking | SHOP-FLOOR | supported | supported | shared Premium theme |
| `production_preparation_station_screen.dart` | tracking | SHOP-FLOOR | supported | supported | shared Premium theme |
| `production_reports_hub_screen.dart` | tracking | REPORT | supported | supported | shared Premium theme |
| `production_tracking_ai_reports_screen.dart` | tracking | REPORT | supported | supported | shared Premium theme |
| `production_tracking_devices_screen.dart` | tracking | SHOP-FLOOR | supported | supported | shared Premium theme |
| `production_tracking_shifts_screen.dart` | tracking | SHOP-FLOOR | supported | supported | shared Premium theme |
| `quality_trend_by_line_report_screen.dart` | tracking | REPORT | supported | supported | shared Premium theme |
| `waste_by_product_report_screen.dart` | tracking | REPORT | supported | supported | shared Premium theme |
| `waste_by_scrap_type_report_screen.dart` | tracking | REPORT | supported | supported | shared Premium theme |
| `work_center_create_screen.dart` | work_centers | FORM | supported | supported | shared Premium theme |
| `work_center_details_screen.dart` | work_centers | DETAIL | supported | supported | shared Premium theme |
| `work_center_edit_screen.dart` | work_centers | FORM | supported | supported | shared Premium theme |
| `work_centers_list_screen.dart` | work_centers | LIST | supported | supported | shared Premium theme |
| `capa_detail_screen.dart` | quality | DETAIL | supported | supported | shared Premium theme |
| `capa_tracking_screen.dart` | quality | SHOP-FLOOR | supported | supported | shared Premium theme |
| `control_plan_edit_screen.dart` | quality | FORM | supported | supported | shared Premium theme |
| `control_plans_list_screen.dart` | quality | LIST | supported | supported | shared Premium theme |
| `execute_inspection_screen.dart` | quality | MASTER DATA | supported | supported | shared Premium theme |
| `inspection_plan_edit_screen.dart` | quality | FORM | supported | supported | shared Premium theme |
| `inspection_plans_list_screen.dart` | quality | LIST | supported | supported | shared Premium theme |
| `inspection_results_list_screen.dart` | quality | LIST | supported | supported | shared Premium theme |
| `internal_audit_create_screen.dart` | quality | FORM | supported | supported | shared Premium theme |
| `internal_audit_detail_screen.dart` | quality | DETAIL | supported | supported | shared Premium theme |
| `internal_audit_list_screen.dart` | quality | LIST | supported | supported | shared Premium theme |
| `ncr_action_history_hub_screen.dart` | quality | LIST | supported | supported | shared Premium theme |
| `ncr_claim_create_screen.dart` | quality | FORM | supported | supported | shared Premium theme |
| `ncr_closure_task_screen.dart` | quality | MASTER DATA | supported | supported | shared Premium theme |
| `ncr_detail_screen.dart` | quality | DETAIL | supported | supported | shared Premium theme |
| `ncr_list_screen.dart` | quality | LIST | supported | supported | shared Premium theme |
| `ncr_open_actions_list_screen.dart` | quality | LIST | supported | supported | shared Premium theme |
| `ncr_recheck_execution_evidence_screen.dart` | quality | SHOP-FLOOR | supported | supported | shared Premium theme |
| `ncr_recheck_task_screen.dart` | quality | MASTER DATA | supported | supported | shared Premium theme |
| `ncr_rework_execution_evidence_screen.dart` | quality | SHOP-FLOOR | supported | supported | shared Premium theme |
| `ncr_rework_executor_task_screen.dart` | quality | MASTER DATA | supported | supported | shared Premium theme |
| `ncr_rework_executor_tasks_list_screen.dart` | quality | LIST | supported | supported | shared Premium theme |
| `qms_management_report_screen.dart` | quality | REPORT | supported | supported | shared Premium theme |
| `qms_methodology_reference_screen.dart` | quality | MASTER DATA | supported | supported | shared Premium theme |
| `qms_pfmea_edit_screen.dart` | quality | FORM | supported | supported | shared Premium theme |
| `qms_pfmea_list_screen.dart` | quality | LIST | supported | supported | shared Premium theme |
| `quality_dashboard_screen.dart` | quality | HOME / DASHBOARD | supported | supported | shared Premium theme |
| `quality_documentation_screen.dart` | quality | MASTER DATA | supported | supported | shared Premium theme |
| `quality_hub_screen.dart` | quality | LIST | supported | supported | M1 composition preserved |
| `carbon_footprint_screen.dart` | sustainability | MASTER DATA | supported | supported | shared Premium theme |
| `attendance_screen.dart` | attendance | MASTER DATA | supported | supported | shared Premium theme |
| `compliance_list_screen.dart` | compliance_documents | LIST | supported | supported | shared Premium theme |
| `employee_edit_screen.dart` | employee_profiles | FORM | supported | supported | shared Premium theme |
| `employee_list_screen.dart` | employee_profiles | LIST | supported | supported | shared Premium theme |
| `workforce_employee_qr_scan_screen.dart` | employee_profiles | MASTER DATA | supported | supported | shared Premium theme |
| `leave_operational_screen.dart` | leave_management | MASTER DATA | supported | supported | shared Premium theme |
| `employee_kpi_dashboard_screen.dart` | performance_feedback | HOME / DASHBOARD | supported | supported | shared Premium theme |
| `feedback_list_screen.dart` | performance_feedback | LIST | supported | supported | shared Premium theme |
| `workforce_recommendations_screen.dart` | recommendations | MASTER DATA | supported | supported | shared Premium theme |
| `workforce_dashboard_screen.dart` | workforce | HOME / DASHBOARD | supported | supported | shared Premium theme |
| `shift_planning_screen.dart` | shift_planning | MASTER DATA | supported | supported | shared Premium theme |
| `qualification_expiry_screen.dart` | skills_matrix | MASTER DATA | supported | supported | shared Premium theme |
| `skills_matrix_screen.dart` | skills_matrix | MASTER DATA | supported | supported | shared Premium theme |
| `training_list_screen.dart` | training_records | LIST | supported | supported | shared Premium theme |
| `about_screen.dart` | about_screen.dart | SETTINGS | supported | supported | shared Premium theme |

Screen files: 265. Mobile and web share each screen. PDF painters stay print output.
