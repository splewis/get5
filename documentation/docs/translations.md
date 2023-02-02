# :material-translate: Translations

Get5 has been translated into a few languages, but some a are still incomplete or could use a grammatical hand. If you
are proficient in a language other than English, you are welcome to open a pull request on GitHub with adjustments or
even entirely new languages. Note that you should be **good** at the language; machine-translations or sloppy
linguistics are worse than defaulting Get5 to English. If you cannot code and have found errors in translations, feel
free to join the [Discord](../community#discord) and let us know.

## How to translate?

Inside the `translations` folder you will find the base `get5.phrases.txt` file which is the English one and the
fallback in case a translation string cannot be found in a client's language. This is the _single source of truth_ and
should be used when translating. Each language has a folder (for instance `fr` for french) within which there is
another `get5.phrases.txt` file, but in French.

Inside each file, the same language specifier is used in front of each string, which **must be identical throughout the
entire language file**.

## Example

!!! example "translations/get5.phrases.txt"

    ```yaml
    "TeamPickedMap"
    {
        "#format"  "{1:s},{2:s},{3:d}" # (1)
        "en"       "{1} picked {2} as map {3}." # (2)
    }
    ```

    1. The `#format` parameter indicates the order and types of parameters. These will *not* be defined in other 
       languages, and you should only provide the language string itself (with its language prefix, i.e. `en`). The
       original file indicates what `{1}`, `{2}` and `{3}` are. In this case, the first and second arguments are strings
       and the third is a number.
    2. Use the English strings and the [reference](#reference) below to determine how to translate the string.

As the string implies, this example is used when a team picks a map, and the output is printed to chat and looks like
this: `Team A picked Dust II as map 2.` The French translation file for this string looks like this:

!!! example "translations/fr/get5.phrases.txt"

    ```yaml
    "TeamPickedMap"
    {
        "fr"  "{1} a choisi {2} comme map {3}."
    }
    ```

## Types of Strings

####`Chat`

:   Displayed in the regular game chat. This is the only type that supports
[color modifiers](../configuration#color-substitutes). You should use the same colors in the same lexical context as the
English translation. All injected variables are colored automatically if required.

####`HintText`

:   Displayed as a ["hint"](https://sourcemod.dev/#/halflife/function.PrintHintText) in the lower center of the screen,
where you would also see the pause or restart alert.

####`KickedNote`

:   Displayed as a modal in the middle of the CS:GO menu after you have been removed from the server. These must **not**
end with a full stop as this is added automatically.

####`Menu`

:   Displayed as an in-game menu where you select/browse using the numbers on your keyboard.

## String Reference {: #reference }

!!! warning

    Some translations are used as sentence components. These are exemplified in **bold**, in
    which case you are only expected to provide the bolded part of the sentence in the translation string.
    [_Bracketed cursive_] indicates an injected variable or component from another string.

| String                                      | Example                                                                                                                                                                      | Type       |
|---------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------|
| `WaitingForCastersReadyInfoMessage`         | Waiting for [_TeamName_] to type [_!ready_] to begin.                                                                                                                        | Chat       |
| `ReadyForMapSelectionInfoMessage`           | Type [_!ready_] when your team is ready for map selection.                                                                                                                   | Chat       |
| `ReadyToRestoreBackupInfoMessage`           | Type [_!ready_] when you are ready to restore the match backup.                                                                                                              | Chat       |
| `ReadyToKnifeInfoMessage`                   | Type [_!ready_] when you are ready to knife.                                                                                                                                 | Chat       |
| `ReadyToStartInfoMessage`                   | Type [_!ready_] when you are ready to begin.                                                                                                                                 | Chat       |
| `YouAreReady`                               | You have been marked as ready.                                                                                                                                               | Chat       |
| `YouAreReadyAuto`                           | NOTE: You have been marked as ready due to game activity.                                                                                                                    | HintText   |
| `TypeUnreadyIfNotReady`                     | Type [_!unready_] if you are not ready.                                                                                                                                      | Chat       |
| `YouAreNotReady`                            | You have been marked as NOT ready.                                                                                                                                           | Chat       |
| `WaitingForEnemySwapInfoMessage`            | [_TeamName_] won the knife round. Waiting for them to type [_!stay_] or [_!swap_].                                                                                           | Chat       |
| `WaitingForGOTVBroadcastEnding`             | The map will change once GOTV has finished broadcasting.                                                                                                                     | Chat       |
| `WaitingForGOTVMapSelection`                | The map will change once GOTV has broadcast the map selection.                                                                                                               | Chat       |
| `NoMatchSetupInfoMessage`                   | No match was set up                                                                                                                                                          | KickedNote |
| `YouAreNotAPlayerInfoMessage`               | You are not a player in this match                                                                                                                                           | KickedNote |
| `TeamIsFullInfoMessage`                     | Your team is full                                                                                                                                                            | KickedNote |
| `TeamForfeitInfoMessage`                    | [_TeamName_] failed to ready up in time and has forfeit.                                                                                                                     | Chat       |
| `TeamMustBeReadyOrForfeit`                  | [_TeamName_] must be ready within [_2:30_] or they will forfeit the match.                                                                                                   | Chat       |
| `TeamsMustBeReadyOrTie `                    | Teams must be ready within [_5:00_] or the match will end in a tie.                                                                                                          | Chat       |
| `MaxPausesUsedInfoMessage`                  | [_TeamName_] has used all their tactical pauses ([_3_]).                                                                                                                     | Chat       |
| `MaxPausesTimeUsedInfoMessage`              | [_TeamName_] has used all their tactical pause time ([_2:30_]).                                                                                                              | Chat       |
| `MatchPausedByTeamMessage`                  | [_PlayerName_] has called for a tactical pause.                                                                                                                              | Chat       |
| `MatchTechPausedByTeamMessage`              | [_PlayerName_] has called for a technical pause.                                                                                                                             | Chat       |
| `TechPausesNotEnabled`                      | Technical pauses are not enabled.                                                                                                                                            | Chat       |
| `TechnicalPauseMidSentence`                 | [_TeamName_] ([_CT_]) **technical pause** ([_1_]/[_2_]).                                                                                                                     | HintText   |
| `TacticalPauseMidSentence`                  | [_TeamName_] ([_CT_]) **tactical pause** ([_1_]/[_2_]).                                                                                                                      | HintText   |
| `TimeRemainingBeforeAnyoneCanUnpausePrefix` | [_TeamName_] ([_CT_]) technical pause ([_1_]/[_2_]). **Time remaining before anyone can unpause**: [_2:30_]                                                                  | HintText   |
| `StopCommandNotEnabled`                     | The stop command is not enabled.                                                                                                                                             | Chat       |
| `StopCommandOnlyAfterRoundStart`            | A request to restart the round cannot be given before the round has started.                                                                                                 | Chat       |
| `StopCommandVotingReset`                    | The request by [_TeamName_] to stop the game was canceled as the round ended.                                                                                                | Chat       |
| `StopCommandRequiresNoDamage`               | A request to restart the round cannot be given once a player has damaged any opposing player.                                                                                | Chat       |
| `StopCommandTimeLimitExceeded`              | A request to restart the round must be given within [_0:30_] after the round has started.                                                                                    | Chat       |
| `PauseTimeRemainingPrefix`                  | [_TeamName_] ([_CT_]) tactical pause. **Remaining pause time**: [_2:15_]                                                                                                     | HintText   |
| `PausedForBackup`                           | The game was restored from a backup. Both teams must unpause to continue.                                                                                                    | HintText   |
| `AwaitingUnpause`                           | [_TeamName_] ([_CT_]) tactical pause. **Awaiting unpause**.                                                                                                                  | HintText   |
| `PausedByAdministrator`                     | An administrator has paused the match.                                                                                                                                       | HintText   |
| `PausesNotEnabled`                          | Pauses are not enabled.                                                                                                                                                      | Chat       |
| `UserCannotUnpauseAdmin`                    | As an admin has called for this pause, it must also be unpaused by an admin.                                                                                                 | Chat       |
| `PauseRequestCanceled`                      | [_TeamName_] canceled their request for a pause.                                                                                                                             | Chat       |
| `PausingTeamCannotUnpauseUntilFreezeTime`   | You cannot unpause before your pause has started.                                                                                                                            | Chat       |
| `PauseRunoutInfoMessage`                    | [_TeamName_] has run out of pause time. Unpausing the match.                                                                                                                 | Chat       |
| `TechPauseRunoutInfoMessage`                | Maximum technical pause length has been reached. Anyone may [_!unpause_] now.                                                                                                | Chat       |
| `TechPauseNoTimeRemaining`                  | [_TeamName_] has no more tech pause time. Please use tactical pauses.                                                                                                        | Chat       |
| `TechPauseNoPausesRemaining`                | [_TeamName_] has no more tech pauses. Please use tactical pauses.                                                                                                            | Chat       |
| `TechPauseAutomaticallyStarted`             | A technical pause was automatically started for [_TeamName_].                                                                                                                | Chat       |
| `MatchUnpauseInfoMessage`                   | [_PlayerName_] unpaused the match.                                                                                                                                           | Chat       |
| `WaitingForUnpauseInfoMessage`              | [_TeamName_] wants to unpause, waiting for Team B to type [_!unpause_].                                                                                                      | Chat       |
| `TeamFailToReadyMinPlayerCheck`             | You must have at least [_3_] player(s) on the server to ready up.                                                                                                            | Chat       |
| `TeamIsReadyForMapSelection`                | [_TeamName_] is ready for map selection.                                                                                                                                     | Chat       |
| `TeamIsReadyToRestoreBackup`                | [_TeamName_] is ready to restore the match backup.                                                                                                                           | Chat       |
| `TeamIsReadyToKnife`                        | [_TeamName_] is ready to knife for sides.                                                                                                                                    | Chat       |
| `TeamIsReadyToBegin`                        | [_TeamName_] is ready to begin the match.                                                                                                                                    | Chat       |
| `TeamIsNoLongerReady`                       | [_TeamName_] is no longer ready.                                                                                                                                             | Chat       |
| `ForceReadyInfoMessage`                     | You may type [_!forceready_] to force-ready your team.                                                                                                                       | Chat       |
| `ForceReadyDisabled`                        | The [_!forceready_] command is disabled, but can enabled with [_get5_allow_force_ready_].                                                                                    | Chat       |
| `TeammateForceReadied`                      | Your team was force-readied by [_PlayerName_].                                                                                                                               | Chat       |
| `AdminForceReadyInfoMessage`                | An admin has force-readied all teams.                                                                                                                                        | Chat       |
| `AdminForceEndInfoMessage`                  | An admin force-ended the match.                                                                                                                                              | Chat       |
| `AdminForceEndWithWinnerInfoMessage`        | An admin force-ended the match, setting [_Team 1_] as the winner.                                                                                                            | Chat       |
| `AdminForcePauseInfoMessage`                | An admin force-paused the match.                                                                                                                                             | Chat       |
| `AdminForceUnPauseInfoMessage`              | An admin unpaused the match.                                                                                                                                                 | Chat       |
| `TeamWantsToReloadCurrentRound`             | [_TeamName_] wants to restore the game to the beginning of the current round. [_TeamName_] must confirm with [_!stop_].                                                      | Chat       |
| `TeamWinningSeriesInfoMessage`              | [_TeamName_] is winning the series [_2_]-[_1_].                                                                                                                              | Chat       |
| `SeriesTiedInfoMessage`                     | The series is tied at [_1_]-[_1_].                                                                                                                                           | Chat       |
| `NextSeriesMapInfoMessage`                  | The next map in the series is [_Nuke_] and it will start in [_1:30_].                                                                                                        | Chat       |
| `TeamWonMatchInfoMessage`                   | [_TeamName_] has won the match.                                                                                                                                              | Chat       |
| `TeamTiedMatchInfoMessage`                  | [_TeamName_] and [_TeamName_] have tied the match.                                                                                                                           | Chat       |
| `TeamWonSeriesInfoMessage`                  | [_TeamName_] has won the series [_2_]-[_1_].                                                                                                                                 | Chat       |
| `MatchFinishedInfoMessage`                  | The match is over                                                                                                                                                            | KickedNote |
| `BackupLoadedInfoMessage`                   | Successfully loaded backup [_backup_file_03.cfg_].                                                                                                                           | Chat       |
| `MatchBeginInSecondsInfoMessage`            | The match will begin in [_3_] seconds.                                                                                                                                       | Chat       |
| `MatchIsLiveInfoMessage`                    | Match is LIVE<br>Match is LIVE<br>Match is LIVE<br>Match is LIVE<br>Match is LIVE                                                                                            | Chat       |
| `KnifeIn5SecInfoMessage`                    | The knife round will begin in 5 seconds.                                                                                                                                     | Chat       |
| `KnifeInfoMessage`                          | Knife!<br>Knife!<br>Knife!<br>Knife!<br>Knife!                                                                                                                               | Chat       |
| `TeamDecidedToStayInfoMessage`              | [_TeamName_] has decided to stay.                                                                                                                                            | Chat       |
| `TeamDecidedToSwapInfoMessage`              | [_TeamName_] has decided to swap.                                                                                                                                            | Chat       |
| `TeamLostTimeToDecideInfoMessage`           | [_TeamName_] will stay since they did not make a decision in time.                                                                                                           | Chat       |
| `ChangingMapInfoMessage`                    | Changing map to [_Nuke_]...                                                                                                                                                  | Chat       |
| `MapDecidedInfoMessage`                     | The maps have been decided:                                                                                                                                                  | Chat       |
| `MapIsInfoMessage`                          | Map [_1_]: [_Nuke_].                                                                                                                                                         | Chat       |
| `TeamPickedMap`                             | [_TeamName_] picked [_Nuke_] as map [_2_].                                                                                                                                   | Chat       |
| `TeamSelectedSide`                          | [_TeamName_] has elected to start as [_CT_] on [_Nuke_].                                                                                                                     | Chat       |
| `TeamBannedMap`                             | [_TeamName_] banned [_Nuke_].                                                                                                                                                | Chat       |
| `CaptainLeftDuringMapSelection`             | A team captain left during map selection. Map selection is paused.                                                                                                           | Chat       |
| `ReadyToResumeMapSelection`                 | Type [_!ready_] when you are ready to resume map selection.                                                                                                                  | Chat       |
| `MatchConfigLoadedInfoMessage`              | Loaded match config.                                                                                                                                                         | Chat       |
| `MoveToCoachInfoMessage`                    | You were moved to the coach position as your team is full.                                                                                                                   | Chat       |
| `ExitCoachSlotHelp`                         | Type [_!coach_] to exit the coach slot.                                                                                                                                      | Chat       |
| `EnterCoachSlotHelp`                        | Type [_!coach_] to become a coach for your team.                                                                                                                             | Chat       |
| `CannotLeaveCoachingTeamIsFull`             | You cannot leave the coach position as your team is full.                                                                                                                    | Chat       |
| `CoachingNotEnabled`                        | Coaching is not enabled. You must set [_sv_coaching_enabled_] to 1.                                                                                                          | Chat       |
| `PlayerIsCoachingTeam`                      | [_PlayerName_] is coaching [_TeamName_].                                                                                                                                     | Chat       |
| `CanOnlyCoachDuringWarmup`                  | You can only change to or from coach during warmup.                                                                                                                          | Chat       |
| `AllCoachSlotsFilledForTeam`                | All coach slots ([_2_]) are currently filled for your team.                                                                                                                  | Chat       |
| `ReadyTag`                                  | **[READY]** PlayerName: Hey, I'm ready...                                                                                                                                    | Chat       |
| `NotReadyTag`                               | **[NOT READY]** PlayerName: Hey, I'm not ready...                                                                                                                            | Chat       |
| `MapSelectionTeamChatOnly`                  | You can only type in team chat during map selection.                                                                                                                         | Chat       |
| `MapSelectionInvalidMap`                    | [_de_dst2_] is not a valid map.                                                                                                                                              | Chat       |
| `MapSelectionPickMapHelp`                   | Use [_!pick_] <map> to pick a map.                                                                                                                                           | Chat       |
| `MapSelectionBanMapHelp`                    | Use [_!ban_] <map> to pick a map.                                                                                                                                            | Chat       |
| `MapSelectionPickSideHelp`                  | Use [_!ct_] or [_!t_] to pick a side.                                                                                                                                        | Chat       |
| `MapSelectionAnnounceCaptains`              | Captain for [_TeamName_]: [_PlayerName_]                                                                                                                                     | Chat       |
| `MapSelectionBan`                           | [_TeamName_] must now **BAN** a map.                                                                                                                                         | Chat       |
| `MapSelectionPick`                          | [_TeamName_] must now **PICK** a map to play as map 1.                                                                                                                       | Chat       |
| `MapSelectionTurnToPick`                    | [_TeamName_] must now [_PICK_] a map to play as map [_1_].                                                                                                                   | Chat       |
| `MapSelectionTurnToBan`                     | [_TeamName_] must now [_BAN_] a map.                                                                                                                                         | Chat       |
| `MapSelectionPickSide`                      | [_TeamName_] must now pick a side to play on [_Nuke_].                                                                                                                       | Chat       |
| `MapSelectionRemainingMaps`                 | **Remaining maps:** Dust II, Nuke, Inferno.                                                                                                                                  | Chat       |
| `MapSelectionCountdown`                     | Map selection commencing in [_3_]...                                                                                                                                         | Chat       |
| `NewVersionAvailable`                       | A newer version of Get5 is available. Please visit [_splewis.github.io/get5_] to update.                                                                                     | Chat       |
| `PrereleaseVersionWarning`                  | You are running an unofficial version of Get5 ([_0.9.0-c7af39a_]) intended for development and testing only. This message can be disabled with [_get5_print_update_notice_]. | Chat       |
| `SurrenderCommandNotEnabled`                | The surrender command is not enabled.                                                                                                                                        | Chat       |
| `SurrenderMinimumRoundDeficit`              | You must be behind by at least [_3_] round(s) in order to surrender.                                                                                                         | Chat       |
| `SurrenderInitiated`                        | A vote to surrender was initiated by [_PlayerName_]. Your team must reach [_3_] votes within [_15_] seconds.                                                                 | Chat       |
| `SurrenderVoteStatus`                       | [_2_] of [_3_] required surrender votes have been cast.                                                                                                                      | Chat       |
| `SurrenderSuccessful`                       | [_TeamName_] has surrendered.                                                                                                                                                | Chat       |
| `SurrenderVoteFailed`                       | Not enough players on your team voted to surrender.                                                                                                                          | Chat       |
| `SurrenderOnCooldown`                       | You must wait [_1:30_] to initiate a new vote to surrender.                                                                                                                  | Chat       |
| `WinByForfeitAvailable`                     | [_TeamName_] left the server. [_TeamName_] can now type [_!ffw_] to initiate a countdown to win as long as their team is full.                                               | Chat       |
| `WinByForfeitRequiresFullTeam`              | You must have a full team in order to request or cancel a win by forfeit.                                                                                                    | Chat       |
| `WinByForfeitAlreadyRequested`              | A request to win by forfeit is already pending.                                                                                                                              | Chat       |
| `WinByForfeitCountdownStarted`              | [_TeamName_] will win in [_0:45_] unless a player from [_TeamName_] rejoins the game. This request can be canceled with [_!cancelffw_].                                      | Chat       |
| `WinByForfeitCountdownCanceled`             | The request from [_TeamName_] to win by forfeit was canceled.                                                                                                                | Chat       |
| `TeamForfeited`                             | [_TeamName_] forfeited the series.                                                                                                                                           | Chat       |
| `AllPlayersLeftTieCountdown`                | Both teams have left the server. At least one player from each team must rejoin within [_0:45_] or the series will end in a tie.                                             | Chat       |
| `TieCountdownCanceled`                      | The countdown to a tie was canceled as both teams now have players.                                                                                                          | Chat       |

## Supported Languages {: #supported-languages }

These are the languages Get5 supports. The links will take you to the source translation file for the language on
GitHub. Most languages are incomplete, and if a translation string is missing, the English default will be used.

#### :flag_gb: [English](https://github.com/splewis/get5/blob/development/translations/get5.phrases.txt) (default) {: #en }

#### :flag_fr: [French](https://github.com/splewis/get5/tree/development/translations/fr/get5.phrases.txt) {: #fr }

#### :flag_de: [German](https://github.com/splewis/get5/tree/development/translations/de/get5.phrases.txt) {: #de }

#### :flag_es: [Spanish](https://github.com/splewis/get5/tree/development/translations/es/get5.phrases.txt) {: #es }

#### :flag_cn: [Chinese](https://github.com/splewis/get5/tree/development/translations/chi/get5.phrases.txt) {: #cn }

#### :flag_dk: [Danish](https://github.com/splewis/get5/tree/development/translations/da/get5.phrases.txt) {: #da }

#### :flag_hu: [Hungarian](https://github.com/splewis/get5/tree/development/translations/hu/get5.phrases.txt) {: #hu }

#### :flag_pl: [Polish](https://github.com/splewis/get5/tree/development/translations/pl/get5.phrases.txt) {: #pl }

#### :flag_pt: [Portuguese](https://github.com/splewis/get5/tree/development/translations/pt/get5.phrases.txt) {: #pt }

#### :flag_ru: [Russian](https://github.com/splewis/get5/tree/development/translations/ru/get5.phrases.txt) {: #ru }
