import 'package:flutter/material.dart';

import '../models/ooe_live_status.dart';
import '../ooe_help_texts.dart';
import 'ooe_info_icon.dart';

class OoeLiveStatusCard extends StatelessWidget {
  final OoeLiveStatus status;

  /// Iz šifrarnika imovine (`assets`) kada postoji, inače `null`.
  final String? machineDisplayName;
  final VoidCallback? onOpenDetails;

  const OoeLiveStatusCard({
    super.key,
    required this.status,
    this.machineDisplayName,
    this.onOpenDetails,
  });

  String _pct(double x) => '${(x * 100).toStringAsFixed(1)} %';

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onOpenDetails,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (machineDisplayName ?? '').trim().isNotEmpty
                              ? machineDisplayName!.trim()
                              : 'Stroj',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if ((machineDisplayName ?? '').trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Referenca: ${status.machineId}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              status.machineId,
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(
                      status.currentState.isEmpty ? '—' : status.currentState,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              if ((status.currentReasonName ?? status.currentReasonCode ?? '')
                  .trim()
                  .isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    status.currentReasonName ??
                        status.currentReasonCode ??
                        '',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _tag('OOE', _pct(status.currentShiftOoe)),
                  _tag('A', _pct(status.availability)),
                  _tag('P', _pct(status.performance)),
                  _tag('Q', _pct(status.quality)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      'Good ${status.goodCount.toStringAsFixed(0)} · Scrap ${status.scrapCount.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ),
                  OoeInfoIcon(
                    tooltip: OoeHelpTexts.liveCardTagsTooltip,
                    dialogTitle: OoeHelpTexts.liveCardTagsTitle,
                    dialogBody: OoeHelpTexts.liveCardTagsBody,
                    iconSize: 18,
                  ),
                ],
              ),
              if (onOpenDetails != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onOpenDetails,
                    child: const Text('Detalji mašine'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String k, String v) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: Colors.grey.shade200,
        child: Text(
          k,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
      label: Text(v),
    );
  }
}
