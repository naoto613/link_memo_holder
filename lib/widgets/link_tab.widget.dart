import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:link_memo_holder/data/advertising.dart';
import 'package:link_memo_holder/data/split_word.dart';

import 'package:link_memo_holder/models/link_card_item.model.dart';
import 'package:link_memo_holder/models/update_catch.model.dart';
import 'package:link_memo_holder/services/fetch_ogp.service.dart';
import 'package:link_memo_holder/widgets/common/action_row.widget.dart';
import 'package:link_memo_holder/widgets/link_tab/link_card.widget.dart';
import 'package:metadata_fetch/metadata_fetch.dart';

class LinkTab extends HookWidget {
  final ValueNotifier<List<LinkCardItem>> linkCardItemsState;
  final ValueNotifier<List<String>> linkContentsState;
  final ValueNotifier<List<String>> linkKindsState;
  final List<String> selectableLinkKinds;
  final ValueNotifier<bool> loadingState;
  final ValueNotifier<UpdateCatch> updateLinkCatchState;
  final String? selectLinkKind;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  const LinkTab({
    Key? key,
    required this.linkCardItemsState,
    required this.linkContentsState,
    required this.linkKindsState,
    required this.selectableLinkKinds,
    required this.loadingState,
    required this.updateLinkCatchState,
    required this.selectLinkKind,
    required this.flutterLocalNotificationsPlugin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double paddingWidth = MediaQuery.of(context).size.width > 550.0
        ? (MediaQuery.of(context).size.width - 550) / 2
        : 5;

    final BannerAd myBanner = BannerAd(
      adUnitId: androidBannerAdvid,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: const BannerAdListener(),
    );

    myBanner.load();

    useEffect(() {
      WidgetsBinding.instance!.addPostFrameCallback((_) async {
        if (updateLinkCatchState.value.linkData != null ||
            updateLinkCatchState.value.targetNumber != null ||
            updateLinkCatchState.value.isRegeneration) {
          List<LinkCardItem> linkCardItems = [];

          if (updateLinkCatchState.value.isRegeneration) {
            // actionRowを再生成
            for (var i = 0; i < linkCardItemsState.value.length; i++) {
              final linkCardItem = linkCardItemsState.value[i];

              final titleExist = linkCardItem.metadata != null &&
                  linkCardItem.metadata!.title == null;

              linkCardItems.add(
                LinkCardItem(
                  linkCard: LinkCard(
                    uri: linkCardItem.uri,
                    metadata: linkCardItem.metadata,
                    actionRow: ActionRow(
                      selectableKinds: selectableLinkKinds,
                      contentsState: linkContentsState,
                      kindsState: linkKindsState,
                      targetNumber: i,
                      updateCatchState: updateLinkCatchState,
                      isLinkTab: true,
                      flutterLocalNotificationsPlugin:
                          flutterLocalNotificationsPlugin,
                      linkTitleEditable: titleExist,
                    ),
                    linkData: linkCardItem.linkData,
                  ),
                  uri: linkCardItem.uri,
                  metadata: linkCardItem.metadata,
                  linkData: linkCardItem.linkData,
                ),
              );
            }
          } else {
            int deletedCount = 0;
            for (var i = 0; i < linkCardItemsState.value.length; i++) {
              final linkCardItem = linkCardItemsState.value[i];
              final titleExist = linkCardItem.metadata != null &&
                  linkCardItem.metadata!.title == null;

              // 変更対象の場合
              if (i == updateLinkCatchState.value.targetNumber) {
                if (updateLinkCatchState.value.isDelete) {
                  // 削除の場合削除カウントを加算
                  deletedCount++;
                } else {
                  // 変更の場合は再作成
                  linkCardItems.add(
                    LinkCardItem(
                      linkCard: LinkCard(
                        uri: linkCardItem.uri,
                        metadata: linkCardItem.metadata,
                        actionRow: ActionRow(
                          selectableKinds: selectableLinkKinds,
                          contentsState: linkContentsState,
                          kindsState: linkKindsState,
                          targetNumber: i,
                          updateCatchState: updateLinkCatchState,
                          isLinkTab: true,
                          flutterLocalNotificationsPlugin:
                              flutterLocalNotificationsPlugin,
                          linkTitleEditable: titleExist,
                        ),
                        linkData: updateLinkCatchState.value.linkData ??
                            linkCardItem.linkData,
                      ),
                      uri: linkCardItem.uri,
                      metadata: linkCardItem.metadata,
                      linkData: updateLinkCatchState.value.linkData ??
                          linkCardItem.linkData,
                    ),
                  );
                }
              } else if (deletedCount > 0) {
                // 削除があった場合はtargetNumberを再構築
                linkCardItems.add(
                  LinkCardItem(
                    linkCard: LinkCard(
                      uri: linkCardItem.uri,
                      metadata: linkCardItem.metadata,
                      actionRow: ActionRow(
                        selectableKinds: selectableLinkKinds,
                        contentsState: linkContentsState,
                        kindsState: linkKindsState,
                        targetNumber: i - deletedCount,
                        updateCatchState: updateLinkCatchState,
                        isLinkTab: true,
                        flutterLocalNotificationsPlugin:
                            flutterLocalNotificationsPlugin,
                        linkTitleEditable: titleExist,
                      ),
                      linkData: linkCardItem.linkData,
                    ),
                    uri: linkCardItem.uri,
                    metadata: linkCardItem.metadata,
                    linkData: linkCardItem.linkData,
                  ),
                );
              } else {
                // そのまま追加
                linkCardItems.add(linkCardItem);
              }
            }

            if (updateLinkCatchState.value.targetNumber == null &&
                updateLinkCatchState.value.linkData != null) {
              // 読み込み中に切り替え
              loadingState.value = true;

              // 登録の場合はlinkDataに値が入っている
              final linkData = updateLinkCatchState.value.linkData!;
              final splitData = linkData.split(splitWord);
              final targetUrl = splitData[0];
              final uri = Uri.parse(targetUrl);
              final Metadata? metadata = await fetchOgp(uri);

              final titleExist = metadata != null && metadata.title == null;
              linkCardItems.add(
                LinkCardItem(
                  linkCard: LinkCard(
                    uri: uri,
                    metadata: metadata,
                    actionRow: ActionRow(
                      selectableKinds: selectableLinkKinds,
                      contentsState: linkContentsState,
                      kindsState: linkKindsState,
                      targetNumber: linkContentsState.value.length - 1,
                      updateCatchState: updateLinkCatchState,
                      isLinkTab: true,
                      flutterLocalNotificationsPlugin:
                          flutterLocalNotificationsPlugin,
                      linkTitleEditable: titleExist,
                    ),
                    linkData: linkData,
                  ),
                  uri: uri,
                  metadata: metadata,
                  linkData: linkData,
                ),
              );

              loadingState.value = false;
            }
          }

          linkCardItemsState.value = linkCardItems;

          // 初期化しておく
          updateLinkCatchState.value = const UpdateCatch(
            targetNumber: null,
            isDelete: false,
            kind: null,
            linkData: null,
            isRegeneration: false,
          );
        }
      });
      return null;
    }, [updateLinkCatchState.value]);

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/link_back.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          right: paddingWidth,
          left: paddingWidth,
          top: 8,
          bottom: 5,
        ),
        child: loadingState.value
            ? const Center(
                child: SpinKitThreeBounce(
                  color: Color.fromARGB(255, 9, 178, 184),
                  size: 30,
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 4,
                      bottom: 7,
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      child: AdWidget(ad: myBanner),
                      width: myBanner.size.width.toDouble(),
                      height: myBanner.size.height.toDouble(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      right: 10,
                      left: 10,
                      top: 4,
                      bottom: 10,
                    ),
                    child: linkCardItemsState.value.isNotEmpty &&
                            (selectLinkKind == null ||
                                linkKindsState.value
                                    .where(
                                        (element) => element == selectLinkKind)
                                    .toList()
                                    .isNotEmpty)
                        ? SizedBox(
                            height: MediaQuery.of(context).size.height - 250,
                            child: ListView.builder(
                              itemBuilder: (context, index) {
                                final displayIndex =
                                    linkCardItemsState.value.length - index - 1;
                                // 分類が設定されていないか、対象の分類だった場合は表示対象に
                                if (selectLinkKind == null ||
                                    linkKindsState.value[displayIndex] ==
                                        selectLinkKind) {
                                  return linkCardItemsState
                                      .value[displayIndex].linkCard;
                                } else {
                                  return Container();
                                }
                              },
                              itemCount: linkCardItemsState.value.length,
                              // height: MediaQuery.of(context).size.height - 165,
                              // child: ListView.builder(
                              //   itemBuilder: (context, index) {
                              //     final displayIndex =
                              //         linkCardItemsState.value.length - index - 1;

                              //     return LinkCardSample(
                              //         sampleNumber: index + 1,
                              //         actionRow: linkCardItemsState
                              //             .value[displayIndex]
                              //             .linkCard
                              //             .actionRow);
                              //   },
                              //   itemCount: 2,
                            ),
                          )
                        : Text(
                            AppLocalizations.of(context).no_link,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
