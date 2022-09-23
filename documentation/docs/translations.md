# :material-translate: Translations

Get5 has been translated into a few languages, but some a are still incomplete or could use a grammatical hand. If you
are proficient in a language other than English, you are welcome to open a pull request on GitHub with adjustments or
even entirely new languages. Note that you should be **good** at the language; machine-translations or sloppy
linguistics are worse than defaulting Get5 to English. If you cannot code and have found errors in translations, feel
free to join the [Discord](../community/#discord) and let us know.

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
    "TeamPickedMapInfoMessage"
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
this: `Team A picked de_dust2 as map 2.` The French translation file for this string looks like this:

!!! example "translations/fr/get5.phrases.txt"

    ```yaml
    "TeamPickedMapInfoMessage"
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
    _Cursive_ text indicates an injected variable.

| String                                      | Example                                                                                                                                                                  | Type       |
|---------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------|
| `WaitingForCastersReadyInfoMessage`         | Waiting for _Team A_ to type _!ready_ to begin.                                                                                                                          | Chat       |
| `ReadyToVetoInfoMessage`                    | Type _!ready_ when your team is ready to veto.                                                                                                                           | Chat       |
| `ReadyToRestoreBackupInfoMessage`           | Type _!ready_ when you are ready to restore the match backup.                                                                                                            | Chat       |
| `ReadyToKnifeInfoMessage`                   | Type _!ready_ when you are ready to knife.                                                                                                                               | Chat       |
| `ReadyToStartInfoMessage`                   | Type _!ready_ when you are ready to begin.                                                                                                                               | Chat       |
| `YouAreReady`                               | You have been marked as ready.                                                                                                                                           | Chat       |
| `YouAreReadyAuto`                           | NOTE: You have been marked as ready due to game activity. Type _!unready_ if you are not ready.                                                                          | HintText   |
| `YouAreNotReady`                            | You have been marked as NOT ready.                                                                                                                                       | Chat       |
| `WaitingForEnemySwapInfoMessage`            | _Team A_ won the knife round. Waiting for them to type _!stay_ or _!swap_.                                                                                               | Chat       |
| `WaitingForGOTVBrodcastEndingInfoMessage`   | The map will change once the GOTV broadcast has ended.                                                                                                                   | Chat       |
| `WaitingForGOTVVetoInfoMessage`             | The map will change once the GOTV broadcast has displayed the map vetoes.                                                                                                | Chat       |
| `NoMatchSetupInfoMessage`                   | No match was set up                                                                                                                                                      | KickedNote |
| `YouAreNotAPlayerInfoMessage`               | You are not a player in this match                                                                                                                                       | KickedNote |
| `TeamIsFullInfoMessage`                     | Your team is full                                                                                                                                                        | KickedNote |
| `TeamForfeitInfoMessage`                    | _Team A_ failed to ready up in time and has forfeit.                                                                                                                     | Chat       |
| `MinutesToForfeitMessage`                   | _Team A_ has _2_ minutes left to ready up or they will forfeit the match.                                                                                                | Chat       |
| `SecondsToForfeitInfoMessage`               | _Team A_ has _30_ seconds left to ready up or they will forfeit the match.                                                                                               | Chat       |
| `MaxPausesUsedInfoMessage`                  | _Team A_ has used all their tactical pauses (_3_).                                                                                                                       | Chat       |
| `MaxPausesTimeUsedInfoMessage`              | _Team A_ has used all their tactical pause time (_2:30_).                                                                                                                | Chat       |
| `MatchPausedByTeamMessage`                  | _PlayerName_ has called for a tactical pause.                                                                                                                            | Chat       |
| `MatchTechPausedByTeamMessage`              | _PlayerName_ has called for a technical pause.                                                                                                                           | Chat       |
| `TechPausesNotEnabled`                      | Technical pauses are not enabled.                                                                                                                                        | Chat       |
| `TechnicalPauseMidSentence`                 | _Team A_ (_CT_) __technical pause__ (_1_/_2_).                                                                                                                           | HintText   |
| `TacticalPauseMidSentence`                  | _Team A_ (_CT_) __tactical pause__ (_1_/_2_).                                                                                                                            | HintText   |
| `TimeRemainingBeforeAnyoneCanUnpausePrefix` | _Team A_ (_CT_) technical pause (_1_/_2_). __Time remaining before anyone can unpause__: _2:30_                                                                          | HintText   |
| `StopCommandNotEnabled`                     | The stop command is not enabled.                                                                                                                                         | Chat       |
| `StopCommandVotingReset`                    | The request by _Team A_ to stop the game was canceled as the round ended.                                                                                                | Chat       |
| `PauseTimeRemainingPrefix`                  | _Team A_ (_CT_) tactical pause. __Remaining pause time__: _2:15_                                                                                                         | HintText   |
| `PausedForBackup`                           | The game was restored from a backup. Both teams must unpause to continue.                                                                                                | HintText   |
| `AwaitingUnpause`                           | _Team A_ (_CT_) tactical pause. __Awaiting unpause__.                                                                                                                    | HintText   |
| `PausedByAdministrator`                     | An administrator has paused the match.                                                                                                                                   | HintText   |
| `PausesNotEnabled`                          | Pauses are not enabled.                                                                                                                                                  | Chat       |
| `UserCannotUnpauseAdmin`                    | As an admin has called for this pause, it must also be unpaused by an admin.                                                                                             | Chat       |
| `PausingTeamCannotUnpauseUntilFreezeTime`   | You cannot unpause before your pause has started. Pause requests cannot be canceled.                                                                                     | Chat       |
| `PauseRunoutInfoMessage`                    | _Team A_ has run out of pause time. Unpausing the match.                                                                                                                 | Chat       |
| `TechPauseRunoutInfoMessage`                | Maximum technical pause length has been reached. Anyone may _!unpause_ now.                                                                                              | Chat       |
| `TechPauseNoTimeRemaining`                  | _Team A_ has no more tech pause time. Please use tactical pauses.                                                                                                        | Chat       |
| `TechPauseNoPausesRemaining`                | _Team B_ has no more tech pauses. Please use tactical pauses.                                                                                                            | Chat       |
| `TechPausePausesRemaining`                  | Technical pauses remaining for _Team A_: _2_                                                                                                                             | Chat       |
| `MatchUnpauseInfoMessage`                   | _PlayerName_ unpaused the match.                                                                                                                                         | Chat       |
| `WaitingForUnpauseInfoMessage`              | _Team A_ wants to unpause, waiting for Team B to type _!unpause_.                                                                                                        | Chat       |
| `PausesLeftInfoMessage`                     | Tactical pauses remaining for _Team A_: _3_                                                                                                                              | Chat       |
| `TeamFailToReadyMinPlayerCheck`             | You must have at least _3_ player(s) on the server to ready up.                                                                                                          | Chat       |
| `TeamReadyToVetoInfoMessage`                | _Team A_ is ready to veto.                                                                                                                                               | Chat       |
| `TeamReadyToRestoreBackupInfoMessage`       | _Team A_ is ready to restore the match backup.                                                                                                                           | Chat       |
| `TeamReadyToKnifeInfoMessage`               | _Team A_ is ready to knife for sides.                                                                                                                                    | Chat       |
| `TeamReadyToBeginInfoMessage`               | _Team A_ is ready to begin the match.                                                                                                                                    | Chat       |
| `TeamNotReadyInfoMessage`                   | _Team A_ is no longer ready.                                                                                                                                             | Chat       |
| `ForceReadyInfoMessage`                     | You may type _!forceready_ to force-ready your team.                                                                                                                     | Chat       |
| `ForceReadyDisabled`                        | The _!forceready_ command is disabled, but can enabled with _get5_allow_force_ready_.                                                                                    | Chat       |
| `TeammateForceReadied`                      | Your team was force-readied by _PlayerName_.                                                                                                                             | Chat       |
| `AdminForceReadyInfoMessage`                | An admin has force-readied all teams.                                                                                                                                    | Chat       |
| `AdminForceEndInfoMessage`                  | An admin force-ended the match.                                                                                                                                          | Chat       |
| `AdminForceEndWithWinnerInfoMessage`        | An admin force-ended the match, setting _Team 1_ as the winner.                                                                                                          | Chat       |
| `AdminForcePauseInfoMessage`                | An admin force-paused the match.                                                                                                                                         | Chat       |
| `AdminForceUnPauseInfoMessage`              | An admin unpaused the match.                                                                                                                                             | Chat       |
| `TeamWantsToReloadCurrentRound`             | _Team A_ wants to restore the game to the beginning of the current round. _Team B_ must confirm with _!stop_.                                                            | Chat       |
| `TeamWinningSeriesInfoMessage`              | _Team A_ is winning the series _2_-_1_.                                                                                                                                  | Chat       |
| `SeriesTiedInfoMessage`                     | The series is tied at _1_-_1_.                                                                                                                                           | Chat       |
| `NextSeriesMapInfoMessage`                  | The next map in the series is _de_nuke_ and it will start in _1:30_.                                                                                                     | Chat       |
| `TeamWonMatchInfoMessage`                   | _Team A_ has won the match.                                                                                                                                              | Chat       |
| `TeamTiedMatchInfoMessage`                  | _Team A_ and _Team B_ have tied the match.                                                                                                                               | Chat       |
| `TeamWonSeriesInfoMessage`                  | _Team A_ has won the series _2_-_1_.                                                                                                                                     | Chat       |
| `MatchFinishedInfoMessage`                  | The match is over                                                                                                                                                        | KickedNote |
| `BackupLoadedInfoMessage`                   | Successfully loaded backup _backup_file_03.cfg_.                                                                                                                         | Chat       |
| `MatchBeginInSecondsInfoMessage`            | The match will begin in _3_ seconds.                                                                                                                                     | Chat       |
| `MatchIsLiveInfoMessage`                    | Match is LIVE<br>Match is LIVE<br>Match is LIVE<br>Match is LIVE<br>Match is LIVE                                                                                        | Chat       |
| `KnifeIn5SecInfoMessage`                    | The knife round will begin in 5 seconds.                                                                                                                                 | Chat       |
| `KnifeInfoMessage`                          | Knife!<br>Knife!<br>Knife!<br>Knife!<br>Knife!                                                                                                                           | Chat       |
| `TeamDecidedToStayInfoMessage`              | _Team A_ has decided to stay.                                                                                                                                            | Chat       |
| `TeamDecidedToSwapInfoMessage`              | _Team A_ has decided to swap.                                                                                                                                            | Chat       |
| `TeamLostTimeToDecideInfoMessage`           | _Team A_ will stay since they did not make a decision in time.                                                                                                           | Chat       |
| `ChangingMapInfoMessage`                    | Changing map to _de_nuke_...                                                                                                                                             | Chat       |
| `MapDecidedInfoMessage`                     | The maps have been decided:                                                                                                                                              | Chat       |
| `MapIsInfoMessage`                          | Map _1_: _de_nuke_.                                                                                                                                                      | Chat       |
| `TeamPickedMapInfoMessage`                  | _Team A_ picked _de_nuke_ as map _2_.                                                                                                                                    | Chat       |
| `TeamSelectSideInfoMessage`                 | _Team A_ has selected to start on _CT_ on _de_nuke_.                                                                                                                     | Chat       |
| `TeamVetoedMapInfoMessage`                  | _Team A_ vetoed _de_nuke_.                                                                                                                                               | Chat       |
| `CaptainLeftOnVetoInfoMessage`              | A captain left during the veto, pausing the veto.                                                                                                                        | Chat       |
| `ReadyToResumeVetoInfoMessage`              | Type _!ready_ when you are ready to resume the veto.                                                                                                                     | Chat       |
| `MatchConfigLoadedInfoMessage`              | Loaded match config.                                                                                                                                                     | Chat       |
| `MoveToCoachInfoMessage`                    | You were moved to the coach position as your team is full.                                                                                                               | Chat       |
| `CannotLeaveCoachingTeamIsFull`             | You cannot leave the coach position as your team is full.                                                                                                                | Chat       |
| `CoachingNotEnabled`                        | Coaching is not enabled. You must set _sv_coaching_enabled_ to 1.                                                                                                        | Chat       |
| `PlayerIsCoachingTeam`                      | _PlayerName_ is coaching _Team A_.                                                                                                                                       | Chat       |
| `CanOnlyCoachDuringWarmup`                  | You can only change to or from coach during warmup.                                                                                                                      | Chat       |
| `AllCoachSlotsFilledForTeam`                | All coach slots (_2_) are currently filled for your team.                                                                                                                | Chat       |
| `ReadyTag`                                  | **[READY]** PlayerName: Hey, I'm ready...                                                                                                                                | Chat       |
| `NotReadyTag`                               | **[NOT READY]** PlayerName: Hey, I'm not ready...                                                                                                                        | Chat       |
| `MapVetoPickMenuText`                       | Select a map to PLAY:                                                                                                                                                    | Menu       |
| `MapVetoPickConfirmMenuText`                | Confirm you want to PLAY _de_nuke_:                                                                                                                                      | Menu       |
| `MapVetoBanMenuText`                        | Select a map to VETO:                                                                                                                                                    | Menu       |
| `MapVetoBanConfirmMenuText`                 | Confirm you want to VETO _de_nuke_:                                                                                                                                      | Menu       |
| `MapVetoSidePickMenuText`                   | Select a side for _de_nuke_:                                                                                                                                             | Menu       |
| `MapVetoSidePickConfirmMenuText`            | Confirm you want to start _CT_:                                                                                                                                          | Menu       |
| `ConfirmPositiveOptionText`                 | Yes                                                                                                                                                                      | Menu       |
| `ConfirmNegativeOptionText`                 | No                                                                                                                                                                       | Menu       |
| `VetoCountdown`                             | Veto commencing in _3_ seconds.                                                                                                                                          | Chat       |
| `NewVersionAvailable`                       | A newer version of Get5 is available. Please visit _splewis.github.io/get5_ to update.                                                                                   | Chat       |
| `PrereleaseVersionWarning`                  | You are running an unofficial version of Get5 (_0.9.0-c7af39a_) intended for development and testing only. This message can be disabled with _get5_print_update_notice_. | Chat       |
| `SurrenderCommandNotEnabled`                | The surrender command is not enabled.                                                                                                                                    | Chat       |
| `SurrenderMinimumRoundDeficit`              | You must be behind by at least _3_ round(s) in order to surrender.                                                                                                       | Chat       |
| `SurrenderInitiated`                        | A vote to surrender was initiated by _PlayerName_. Your team must reach _3_ votes within _15_ seconds.                                                                   | Chat       |
| `SurrenderVoteStatus`                       | _2_ of _3_ required surrender votes have been cast.                                                                                                                      | Chat       |
| `SurrenderSuccessful`                       | _Team A_ has surrendered.                                                                                                                                                | Chat       |
| `SurrenderVoteFailed`                       | Not enough players on your team voted to surrender.                                                                                                                      | Chat       |
| `SurrenderOnCooldown`                       | You must wait _1:30_ to initiate a new vote to surrender.                                                                                                                | Chat       |
| `WinByForfeitAvailable`                     | _Team A_ left the server. _Team B_ can now type _!win_ to initiate a countdown to win as long as their team is full.                                                     | Chat       |
| `WinByForfeitRequiresFullTeam`              | You must have a full team in order to request or cancel a win by forfeit.                                                                                                | Chat       |
| `WinByForfeitAlreadyRequested`              | A request to win by forfeit is already pending.                                                                                                                          | Chat       |
| `WinByForfeitCountdownStarted`              | _Team B_ will win in _0:45_ unless a player from _Team A_ rejoins the game. This request can be canceled with _!cancelwin_.                                              | Chat       |
| `WinByForfeitCountdownCanceled`             | The request from _Team B_ to win by forfeit was canceled.                                                                                                                | Chat       |
| `TeamForfeited`                             | _Team A_ forfeited the series.                                                                                                                                           | Chat       |
| `AllPlayersLeftTieCountdown`                | Both teams have left the server. At least one player from each team must rejoin within _0:45_ or the series will end in a tie.                                           | Chat       |
| `TieCountdownCanceled`                      | The countdown to a tie was canceled as both teams now have players.                                                                                                      | Chat       |

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
