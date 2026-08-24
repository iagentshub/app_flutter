import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/fnc_colors.dart';
import '../../../app/theme/fnc_fonts.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../models/accounts/account_models.dart';
import '../../../models/github/github_device_flow.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/widgets/animated_iagents_mark.dart';
import '../../../shared/widgets/async_state_panel.dart';
import '../../../shared/widgets/attention_badge.dart';
import '../../../shared/widgets/buttons/action_icon_button.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/confirm_action_dialog.dart';
import '../../../shared/widgets/motion/app_modal.dart';
import '../../../shared/widgets/resource_toolbar.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../../../shared/widgets/state_messaging_mixin.dart';
import '../repositories/accounts_repository.dart';

part '../dialogs/account_form_dialog.dart';
part '../dialogs/account_sync_dialog.dart';
part '../dialogs/github_device_flow_dialog.dart';

/// Sección "Proveedores": vincular una o varias cuentas externas
/// (Anthropic/OpenAI/GitHub Copilot/Ollama/NVIDIA/Google — varias del mismo
/// proveedor son válidas) y elegir qué modelos traer de cada una como
/// Connections normales, indistinguibles de una creada a mano. Solo se
/// muestran las cuentas realmente vinculadas — la lista empieza vacía;
/// "Añadir cuenta" es lo que pregunta qué proveedor conectar.
///
/// Vive en el perfil del usuario (antes era una pestaña dentro de
/// Connections); es autónoma y no depende de _ConnectionsPageState.
class ProvidersSection extends StatefulWidget {
  const ProvidersSection({
    required this.apiClient,
    required this.token,
    required this.localeController,
    super.key,
  });

  final ApiClient apiClient;
  final String token;
  final LocaleController localeController;

  @override
  State<ProvidersSection> createState() => _ProvidersSectionState();
}

class _ProvidersSectionState extends State<ProvidersSection>
    with StateMessaging {
  late final AccountsRepository _accountsRepository;
  late final TranslatedTexts _t;
  List<AccountItem> _accounts = const [];
  bool _accountsLoading = true;
  final Set<String> _syncingAccounts = {};

  String _tx(String path) => _t.text(path);

  @override
  void initState() {
    super.initState();
    _accountsRepository = AccountsRepository(apiClient: widget.apiClient);
    _t = TranslatedTexts(
      localeController: widget.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    _loadAccounts();
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  AccountProviderMeta _metaForProvider(String provider) {
    return AccountProviderMeta.all.firstWhere(
      (m) => m.provider == provider,
      orElse: () => AccountProviderMeta(
        provider: provider,
        label: provider,
        requiresApiKey: true,
        usesHost: false,
      ),
    );
  }

  Future<void> _loadAccounts() async {
    final token = widget.token;
    if (token.isEmpty) return;
    refresh(() => _accountsLoading = true);
    try {
      final items = await _accountsRepository.listAccounts(token);
      if (!mounted) return;
      refresh(() {
        _accounts = items;
        _accountsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      refresh(() => _accountsLoading = false);
    }
  }

  Future<void> _openCreateAccountDialog() async {
    final token = widget.token;
    if (token.isEmpty) return;
    final changed = await showAppDialog<bool>(
      context: context,
      builder: (context) => _AccountFormDialog(
        apiClient: widget.apiClient,
        token: token,
        providers: AccountProviderMeta.all,
        tx: _tx,
      ),
    );
    if (changed == true) await _loadAccounts();
  }

  Future<void> _openEditAccountDialog(AccountItem account) async {
    final token = widget.token;
    if (token.isEmpty) return;
    final changed = await showAppDialog<bool>(
      context: context,
      builder: (context) => _AccountFormDialog(
        apiClient: widget.apiClient,
        token: token,
        providers: [_metaForProvider(account.provider)],
        existing: account,
        tx: _tx,
      ),
    );
    if (changed == true) await _loadAccounts();
  }

  Future<void> _unlinkAccount(AccountItem account) async {
    final confirm = await showConfirmActionDialog(
      context,
      title: _tx('providers.unlink_confirm_title'),
      message: _tx('providers.unlink_confirm_body'),
      cancelLabel: _tx('common.cancel'),
      confirmLabel: _tx('providers.unlink_action'),
      destructive: true,
    );
    if (!confirm) return;
    final token = widget.token;
    if (token.isEmpty) return;
    try {
      final deleted = await _accountsRepository.unlinkAccount(
        token,
        account.id,
      );
      showMessage(
        deleted > 0
            ? _tx('providers.unlinked_with_connections')
                  .replaceFirst('{count}', '$deleted')
            : _tx('providers.unlinked'),
      );
      await _loadAccounts();
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(_tx('providers.error_generic'), isError: true);
    }
  }

  Future<void> _syncAccount(AccountItem account) async {
    if (account.provider == 'iagentshub') {
      await _syncHubAccount(account);
      return;
    }
    final token = widget.token;
    if (token.isEmpty) return;
    refresh(() => _syncingAccounts.add(account.id));
    try {
      final preview = await _accountsRepository.testAccount(token, account.id);
      if (!mounted) return;
      if (preview.models.isEmpty) {
        showMessage(_tx('providers.no_models_found'), isError: true);
        return;
      }
      final selected = await showAppDialog<List<String>>(
        context: context,
        builder: (context) => _AccountSyncDialog(
          models: preview.models,
          alreadySynced: account.models.toSet(),
          tx: _tx,
        ),
      );
      if (selected == null) return;
      final updated = await _accountsRepository.syncAccount(
        token,
        account.id,
        models: selected,
      );
      if (!mounted) return;
      refresh(() {
        final idx = _accounts.indexWhere((a) => a.id == account.id);
        if (idx != -1) _accounts[idx] = updated;
      });
      final summary = updated.syncSummary;
      final parts = <String>[
        '${summary?.connectionsCreated ?? 0} ${_tx('providers.summary_created')}',
        '${summary?.connectionsUpdated ?? 0} ${_tx('providers.summary_updated')}',
        if ((summary?.connectionsDeleted ?? 0) > 0)
          '${summary!.connectionsDeleted} ${_tx('providers.summary_deleted')}',
      ];
      showMessage('${_tx('providers.sync_done')}: ${parts.join(' · ')}');
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(_tx('providers.error_generic'), isError: true);
    } finally {
      if (mounted) refresh(() => _syncingAccounts.remove(account.id));
    }
  }

  /// Para `iagentshub` no hay modelos que elegir: el sync trae de golpe
  /// agentes/skills/conocimiento/conexiones del hub remoto (mismo
  /// comportamiento que el botón "Sincronizar" de una Connection tipo
  /// iagentshub, reutilizado por el backend vía `_run_hub_sync`).
  Future<void> _syncHubAccount(AccountItem account) async {
    final token = widget.token;
    if (token.isEmpty) return;
    refresh(() => _syncingAccounts.add(account.id));
    try {
      final updated = await _accountsRepository.syncAccount(token, account.id);
      if (!mounted) return;
      refresh(() {
        final idx = _accounts.indexWhere((a) => a.id == account.id);
        if (idx != -1) _accounts[idx] = updated;
      });
      final summary = updated.hubSyncSummary;
      if (summary == null) {
        showMessage(_tx('providers.sync_done'));
        return;
      }
      final parts = <String>[
        '${summary.agents} ${_tx('providers.summary_agents')}',
        '${summary.skills} ${_tx('providers.summary_skills')}',
        '${summary.knowledge} ${_tx('providers.summary_knowledge')}',
        '${summary.connections} ${_tx('providers.summary_connections')}',
      ];
      showMessage(
        summary.ok
            ? '${_tx('providers.sync_done')}: ${parts.join(' · ')}'
            : '${_tx('providers.sync_partial')}: ${summary.errors.join(', ')}',
        isError: !summary.ok,
      );
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(_tx('providers.error_generic'), isError: true);
    } finally {
      if (mounted) refresh(() => _syncingAccounts.remove(account.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_accountsLoading) {
      return const AsyncStatePanel.loading();
    }
    return RefreshIndicator(
      onRefresh: _loadAccounts,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          ResourceToolbar(
            actions: [
              AppIconButton.filled(
                onPressed: _openCreateAccountDialog,
                icon: const Icon(Icons.add),
                tooltip: _tx('providers.add_account'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_accounts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  _tx('providers.not_linked'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            for (final account in _accounts)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildAccountCard(account),
              ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(AccountItem account) {
    final meta = _metaForProvider(account.provider);
    final syncing = _syncingAccounts.contains(account.id);
    final hasCustomName = account.name.isNotEmpty;
    final title = hasCustomName ? account.name : meta.label;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: FncFonts.size14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (hasCustomName) ...[
                  const SizedBox(width: 8),
                  _accountSummaryChip(meta.label),
                ],
                if (account.credentialsUnreadable) ...[
                  const SizedBox(width: 8),
                  AttentionBadge(
                    label: _tx('connections.credential_unreadable_badge'),
                    tooltip: _tx('connections.credential_unreadable_hint'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              [
                if (account.provider == 'iagentshub') ...[
                  if (account.username.isNotEmpty) account.username,
                  if (account.url.isNotEmpty) account.url,
                ] else ...[
                  if (account.apiKeyMasked.isNotEmpty) account.apiKeyMasked,
                  if (account.host.isNotEmpty) account.host,
                ],
                if (account.lastSyncedAt.isNotEmpty)
                  '${_tx('providers.last_synced')}: ${account.lastSyncedAt}',
              ].join(' · '),
              style: const TextStyle(fontSize: FncFonts.size12),
            ),
            if (account.hubSyncSummary != null) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _accountSummaryChip(
                    '${account.hubSyncSummary!.agents} ${_tx('providers.summary_agents')}',
                  ),
                  _accountSummaryChip(
                    '${account.hubSyncSummary!.skills} ${_tx('providers.summary_skills')}',
                  ),
                  _accountSummaryChip(
                    '${account.hubSyncSummary!.knowledge} ${_tx('providers.summary_knowledge')}',
                  ),
                  _accountSummaryChip(
                    '${account.hubSyncSummary!.connections} ${_tx('providers.summary_connections')}',
                  ),
                ],
              ),
            ] else if (account.syncSummary != null) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _accountSummaryChip(
                    '${account.models.length} ${_tx('providers.summary_connections')}',
                  ),
                  _accountSummaryChip(
                    '${account.syncSummary!.agentsCount} ${_tx('providers.summary_agents')}',
                  ),
                  _accountSummaryChip(
                    '${account.syncSummary!.skillsPrivateCount} ${_tx('providers.summary_skills')}',
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                SecondaryButton.icon(
                  onPressed: syncing ? null : () => _syncAccount(account),
                  icon: syncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: IAgentsLoadingMark(),
                        )
                      : const Icon(Icons.sync),
                  label: Text(_tx('providers.sync_action')),
                ),
                const Spacer(),
                ActionIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: _tx('common.edit'),
                  onPressed: () => _openEditAccountDialog(account),
                ),
                ActionIconButton(
                  icon: Icons.link_off,
                  tooltip: _tx('providers.unlink_action'),
                  danger: true,
                  onPressed: () => _unlinkAccount(account),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountSummaryChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontSize: FncFonts.size11)),
    );
  }
}
