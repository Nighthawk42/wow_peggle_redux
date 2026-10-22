local _, ns = ...

-- English strings, keyed as in the original addon (ns.L["KEY"]).
ns.L = {
    ["ABOUT"] = "ABOUT",
    ["ABOUT_TEXT1"] = "The Peggle Institute has opened a branch in Azeroth!\n\n"
        .. "After we successfully brought the Bejeweled experience into "
        .. "WoW, the PopCap Guild decided to tackle another of our favorite things: Peggle.\n\n"
        .. "We wanted something more competitive that we could use to settle "
        .. "loot disputes and challenge each other while we waited for that "
        .. "last raid member to log on. We've packed in some great touches "
        .. "for the add-on version of Peggle, and now it's ready to be shared with the world!",
    ["ABOUT_TEXT2"] = "Peggle Redux is maintained by the community at\n|cFFFF66CCgithub.com/Nighthawk42/wow_peggle_redux|r",
    ["ABOUT_TEXT3"] = "(C) 2007, 2009 PopCap Games, Inc. All rights reserved.",
    ["ABOUT_TEXT4"] = "Version ",
    ["_BALL_SCORE"] = "+10,000",
    ["BALLS_LEFT1"] = "%d BALLS LEFT",
    ["BALLS_LEFT2"] = "LAST BALL!",
    ["BEAT_THIS_LEVEL1"] = "Beat this level to earn\n+1 talent point!",
    ["BEAT_THIS_LEVEL2"] = "Clear all pegs to earn\n+1 talent point!",
    ["BEAT_THIS_LEVEL3"] = "+1 talent point earned\n(Beat level)",
    ["BEAT_THIS_LEVEL4"] = "+1 talent point earned\n(Full clear)",
    ["BRAG"] = "What channel would you like to brag to?",
    ["BRAG_NO_CHANNEL"] = "You are no longer in the channel %s. Pick another one.",
    ["CHALLENGE"] = "BATTLE",
    ["CHALLENGE_DESC"] = "Select a battle to view its details\nor create a new battle",
    ["CHALLENGE_DESC1"] = "Click a name to quickly add/remove it!",
    ["CHALLENGE_DESC2"] = "|cFFFF8C00CHAT CHANNELS: Adding a custom chat channel will invite all in the chat channel at the time of battle creation. This will not invite offline users, nor users who do not have the addon installed.\n\nYou may only invite custom channels.",
    ["CHALLENGE_DESC3"] = "Note: Offline users will not receive the battle until they come online while another invitee or you are also online.",
    ["CHALLENGE_CAT1"] = "From:",
    ["CHALLENGE_CAT2"] = "Level:",
    ["CHALLENGE_CAT3"] = "Shots:",
    ["CHALLENGE_CAT4"] = "Current Standing:",
    ["CHALLENGE_CAT5"] = "Time Left:",
    ["CHALLENGE_CAT6"] = "Note to Players:",
    ["CHALLENGE_LIST"] = "Battle List",
    ["CHALLENGE_DETAILS"] = "Battle Details",
    ["CHALLENGE_DUR"] = "BATTLE DURATION",
    ["CHALLENGE_GUILD1"] = "View Offline Guild Members",
    ["CHALLENGE_GUILD2"] = "Sort by Online Status",
    ["CHALLENGE_INVITE1"] = "|cFFFF8C00FRIENDS",
    ["CHALLENGE_INVITE2"] = "|cFFFF8C00GUILD",
    ["CHALLENGE_INVITE3"] = "|cFFFF8C00CHANNEL",
    ["CHALLENGE_LIMIT"] = "Limit of 5 Active\nBattles at once",
    ["CHALLENGE_NEW"] = "NEW BATTLE",
    ["CHALLENGE_NONE"] = "NO BATTLE SELECTED",
    ["CHALLENGE_RANK"] = "%d of %d",
    ["CHALLENGE_SHOTS"] = "NUMBER OF SHOTS",
    ["CHALLENGE_SORT_ONLINE"] = "Sort by Online Status",
    ["CHALLENGE_REPLAYS"] = "NUMBER OF REPLAYS",
    ["CHALLENGE_VIEW_OFFLINE"] = "View Offline Guild Members",
    ["CHALLENGE_YOUR_STATUS"] = "Your Status:",
    ["_BATTLE_INVITE"] = "%s invited you to a Peggle battle on %s. Open the Battle tab to play.",
    ["CHAR_SELECT"] = "CHARACTER SELECT",
    ["CREDITS"] = "CREDITS",
    ["CREDITS1"] = "Programmer",
    ["CREDITS1a"] = "Michael Fromwiller",
    ["CREDITS2"] = "Producer",
    ["CREDITS2a"] = "T. Carl Kwoh",
    ["CREDITS3"] = "Artists",
    ["CREDITS3a"] = "Tysen Henderson\n" .. "Noah Maas",
    ["CREDITS4"] = "Level Design",
    ["CREDITS4a"] = "Stephen Notley",
    ["CREDITS5"] = "Quality Assurance",
    ["CREDITS5a"] = "Ed Miller\n" .. "Eric Olson",
    ["CREDITS6"] = "Peggle Credits",
    ["CREDITS6a"] = "Sukhbir Sidhu\n"
        .. "Brian Rothstein\n"
        .. "Eric Tams\n"
        .. "Jeremy Bilas\n"
        .. "Walter Wilson\n"
        .. "Matthew Holmberg",
    ["CREDITS7"] = "Special Thanks",
    ["CREDITS7a"] = "Jason Kapalka\n"
        .. "Dave Haas\n"
        .. "Blizzard Entertainment\n"
        .. "Jen Chess\n"
        .. "Scott Lantz\n"
        .. "Anthony Coleman",
    ["CREDITS8"] = "Beta Testers",
    ["CREDITS8a"] = "BraveOne - Aerie Peak [A]\n"
        .. "Johndoe - Executus EU [A]\n"
        .. "Kinu - Ravencrest [H]\n"
        .. "Klauen - Blackrock [H]\n"
        .. "Lothaer - Spinebreaker [A]\n"
        .. "Naiad - Dalaran [A]",
    ["CREDITS8b"] = "Palasadia - Doomhammer [H]\n"
        .. "Polgarra - Terokkar [A]\n"
        .. "Smashtastic - Khadgar [A]\n"
        .. "Sythalin - Thunderlord[A]\n"
        .. "Thanotos- Turalyon[A]\n"
        .. "Vodax - Dalaran [A]\n"
        .. "Zoquara - Nordrassil [A]",
    ["DUEL"] = "DUEL",
    ["DUEL_BREAKDOWN1"] = "Your Score: %s",
    ["DUEL_BREAKDOWN1a"] = "Opponent's Score: %s",
    ["DUEL_BREAKDOWN2"] = "Talent: |cFFFFFFFF%s",
    ["DUEL_BREAKDOWN3"] = "Style: |cFFFFFFFF%s",
    ["DUEL_BREAKDOWN4"] = "Fever: |cFFFFFFFF%s",
    ["DUEL_CHALLENGE"] = "%s has challenged you to a duel!",
    ["DUEL_FORFEIT1"] = "|cFFFF0000You forfeited the duel!",
    ["DUEL_FORFEIT2"] = "|cFFFF0000Opponent forfeited the duel!",
    ["_DUEL_HISTORY"] = "Last 10 opponents:",
    ["_DUEL_NO_HISTORY"] = "No one has been dueled!",
    ["DUEL_OPP_WL"] = "Win/Loss vs %s: %d - %d",
    ["DUEL_RESULTS"] = "DUEL RESULTS",
    ["DUEL_RESULT1"] = "WAITING ON\n%s",
    ["DUEL_RESULT2"] = "|cFF00FF00DEFEATED\n%s",
    ["DUEL_RESULT3"] = "|cFFFF0000DEFEATED BY\n%s",
    ["DUEL_RESULT4"] = "|cFFFF0000DUEL WAS\nFORFEITED",
    ["_DUEL_RESULT_TIE"] = "|cFFFFFF00TIED WITH\n%s",
    ["DUEL_SCORE1"] = "Your Score: %s",
    ["DUEL_SCORE2"] = "Opponent Score: %s",
    ["DUEL_STATUS"] = "DUEL INVITE STATUS",
    ["DUEL_STATUS1"] = "Sending duel invite...",
    ["DUEL_STATUS2"] = "Waiting for user to accept duel request...",
    ["DUEL_STATUS3"] = "User declined the duel request.",
    ["DUEL_STATUS4"] = "User does not have Peggle addon turned on.",
    ["DUEL_STATUS5"] = "User is currently being challenged. Try again in a few minutes.",
    ["DUEL_STATUS6"] = "Challenger cancelled the duel.",
    ["DUEL_TIME"] = "Duel time remaining: %s",
    ["DUEL_TOTAL_WL"] = "Total Win/Loss: %d - %d",
    ["DUEL_WAITING"] = "Your opponent is still playing...",
    ["_EXPIRED"] = "Expired",
    ["FORFEIT"] = "Forfeit",
    ["_FREE_BALL"] = "FREE BALL!",
    ["FREE_BALL2"] = "FREE\nBALL",
    ["_FREE_BALL_DUEL"] = "BUCKET BONUS\n%s",
    ["GENERATING_NAMES"] = "Generating name list for custom channels...",
    ["HOW_TO_PLAY1"] = "Basic Gameplay",
    ["HOW_TO_PLAY2"] = "Duel Mode",
    ["HOW_TO_PLAY2a"] = "Duel Mode lets you challenge another player to a 1-on-1 ten-ball "
        .. "game of Peggle. Choose a level and type in the name of the player "
        .. "you want to challenge, then hit Play!\n\n"
        .. "Players must be online and have the add-on in order to participate, "
        .. "and if they are already in another duel you won't be able to challenge "
        .. "them until they are finished.\n\n"
        .. "Duel mode stores your last ten opponents as a handy drop-down so you can "
        .. "quickly get a rematch.",
    ["HOW_TO_PLAY2b"] = "After each duel, the summary screen shows how you fared vs your opponent "
        .. "and gives a breakdown of the point scoring. It also displays which character "
        .. "your opponent used, as well as how many levels they've beaten or gotten a "
        .. "100% clear on.",
    ["HOW_TO_PLAY3"] = "Battle Mode",
    ["HOW_TO_PLAY3a"] = "Battle Mode lets you set up special multiplayer contests with your friends "
        .. "and guildmates. You can pick the level, adjust how many shots each person is "
        .. "allowed, and how long the battle will be active for. Then send out invitations "
        .. "to your friends!\n\n"
        .. "When you click the Battle Mode tab you can either select an existing "
        .. "Battle that you've entered, or create a new one. If you select one that "
        .. "you've already played, you can see the current leaderboard.\n\n"
        .. "The leaderboard also shows icons to indicate which character the player used "
        .. "as well as the number of levels they've beaten and how many 100% clears they've "
        .. "achieved.",
    ["HOW_TO_PLAY3b"] = "Battles that have run out of time will eventually decay off your list.",
    ["HOW_TO_PLAY4"] = "Peggle Loot",
    ["HOW_TO_PLAY4a"] = "Peggle Loot is a fun way to distribute loot in a Master Looter party or raid. "
        .. "When activated, all players in the party or raid with the add-on will get the "
        .. "option to play a single shot high score challenge for the item. Whoever scores "
        .. "the highest wins the right to the item!\n\n"
        .. "If you are the Loot Master in a party or raid, simply type |cFFFFFF00/peggleloot|r to "
        .. "initiate the challenge. Optionally, you can also shift-click the item to add "
        .. "an item link after the peggleloot command.",
    ["HOW_TO_PLAY4b"] = "The addon will pick a random level, and then send that challenge to all members "
        .. "of the party or raid. They will have the option to play or pass. If they play, "
        .. "they get a single shot to score as many points as possible.\n\n"
        .. "To make it fair, talents are disabled for the shot and all users are defaulted "
        .. "to Splork. Players have 30 seconds to complete their shots from when the Peggle "
        .. "Loot challenge is activated.\n\n"
        .. "Once all players have competed, their scores are shown and the winner declared! "
        .. "The Loot Master should then assign the loot to the winner of the challenge.",
    ["INVITEES"] = "INVITEES",
    ["INVITED"] = "|cFFFF8C00(%d INVITED)",
    ["INVITE_PERSON"] = "INVITE INDIVIDUAL:",
    ["INVITE_NOTE"] = "NOTE TO INVITEES",
    ["LEGAL1"] = "(c) 2000, 2009 PopCap Games Inc. All right reserved",
    ["LEGAL2"] = "(c)2007, 2009 PopCap Games, Inc.  All rights reserved.  This application is "
        .. "being made available free of charge for your personal, non-commercial entertainment "
        .. 'use, and is provided "as is", without any warranties.  PopCap Games, Inc. will have '
        .. "no liability to you or anyone else if you choose to use it.  See readme.txt for details.",
    ["_LEVEL_INFO"] = "Level %d: %s",
    ["_LEVEL_NAME1"] = "Ironforge",
    ["_LEVEL_NAME2"] = "Orgrimmar",
    ["_LEVEL_NAME3"] = "Stormwind",
    ["_LEVEL_NAME4"] = "Undercity",
    ["_LEVEL_NAME5"] = "Darnassus",
    ["_LEVEL_NAME6"] = "Thunder Bluff",
    ["_LEVEL_NAME7"] = "Dark Portal",
    ["_LEVEL_NAME8"] = "Exodar",
    ["_LEVEL_NAME9"] = "Silvermoon City",
    ["_LEVEL_NAME10"] = "Shattrath City",
    ["_LEVEL_NAME11"] = "Dalaran",
    ["_LEVEL_NAME12"] = "Icecrown Citadel",
    ["MENU"] = "MENU",
    ["MOST_RECENT"] = "MOST RECENT:",
    ["MOUSE_OVER"] = "Mouse over a talent for more information",
    ["NEW"] = " |cffffff00(NEW!)",
    ["_NEXT"] = "NEXT ",
    ["NO_SCORE"] = "PLAY LEVEL TO EARN A SCORE!",
    ["NOT_PLAYED"] = "Not yet played",
    ["OPPONENT"] = "OPPONENT:",
    ["OPPONENT_NOTE"] = "NOTE TO OPPONENT",
    ["OPPONENT_NOTE2"] = "NOTE FROM OPPONENT",
    ["OPT_TRANS_DEFAULT"] = "Mouse-on Transparency",
    ["OPT_TRANS_MOUSE"] = "Mouse-off Transparency",
    ["OPT_MINIMAP"] = "Show Mini-map Icon",
    ["OPT_NEW_ON_FLIGHT"] = "New Game on Flight Start",
    ["OPT_SOUNDS"] = "Sounds:",
    ["OPT_SOUNDS_NORMAL"] = "Normal",
    ["OPT_SOUNDS_QUIET"] = "Quiet",
    ["OPT_SOUNDS_OFF"] = "Off",
    ["OPT_LOCK"] = "Lock Window",
    ["OPT_COLORBLIND"] = "Color Blind Mode",
    ["OPT_HIDEOUTDATED"] = "Hide Outdated Chat Notifications",
    ["OPT_AUTO_OPEN"] = "Auto-Open:",
    ["OPT_AUTO_OPEN1"] = "On Flight Start",
    ["OPT_AUTO_OPEN2"] = "On Death",
    ["OPT_AUTO_OPEN3"] = "On Log-in",
    ["OPT_AUTO_OPEN4"] = "Duel Invite",
    ["OPT_AUTO_CLOSE"] = "Auto-Close:",
    ["OPT_AUTO_CLOSE1"] = "On Flight End",
    ["OPT_AUTO_CLOSE2"] = "On Ready Check",
    ["OPT_AUTO_CLOSE3"] = "On Enter Combat",
    ["OPT_AUTO_CLOSE4"] = "Duel Complete",
    ["OPT_AUTO_CLOSE5"] = "Peggle Loot Complete",
    ["OPT_DUEL_INVITES"] = "Duel/Battle Invites:",
    ["OPT_DUEL_INVITES1"] = "Chatbox Text Alert",
    ["OPT_DUEL_INVITES2"] = "Raid Warning Text Alert",
    ["OPT_DUEL_INVITES3"] = "Mini-map Icon Alert",
    ["OPT_DUEL_INVITES4"] = "Auto-decline Duels",
    ["OPTIONAL"] = "|cFFFF8C00(OPTIONAL)",
    ["ORANGE_PEGS"] = "Orange\nPegs",
    ["OUT_OF_DATE"] = "|cFFFFFFFFA newer version of Peggle Redux is out! Get it from |r|cFFFFFF00github.com/Nighthawk42/wow_peggle_redux|r",
    ["_OUTDATED"] = "%s has invited you to a %s using an old version of this addon. Unfortunately, the versions are no longer compatible. Please ask them to upgrade to the latest version.",
    ["_OUTDATED_PEER"] = "%s is using an older version of Peggle Redux. Duels, battles and Peggle Loot only work between matching versions, so ask them to update.",
    ["_PEGS_HIT"] = "%s x %d |4PEG:PEGS",
    ["_PEGGLE_ISSUE1"] = "[Peggle] We're very sorry but it appears the battle data being saved is invalid and was not saved. Please report it at github.com/Nighthawk42/wow_peggle_redux/issues with as much detail as possible.",
    ["PEGGLE_ISSUE2"] = "Part of the Peggle addon is corrupt. Please re-download the Peggle addon to fix this issue.",
    ["PEGGLELOOT_DESC"] = "Highest Scoring Single Shot Wins",
    ["_PEGGLELOOT_ISACTIVE"] = "Peggle Loot is already active! %d seconds remain in current challenge.",
    ["_PEGGLELOOT_NOTIFY"] = "Peggle One-Shot Loot System Initialized for %s! Results released in 40 seconds. If you do not have the Peggle Addon, you're missing out!",
    ["_PEGGLELOOT_CHAT_REMAINING"] = "Peggle Loot results in %d seconds!",
    ["_PEGGLELOOT_NOTMASTERLOOTER"] = "PeggleLoot requires you to be the Master Looter.",
    ["_PEGGLELOOT_NOTLEADER"] = "Peggle Loot requires you to be the group leader or an assistant.",
    ["_PEGGLELOOT_NOGROUP"] = "Peggle Loot needs a party or raid.",
    ["_PEGGLELOOT_NOWINNER"] = "*** No winner found! ***",
    ["PEGGLELOOT_REMAINING"] = "Time remaining: %d sec",
    ["_PEGGLELOOT_RESULTS"] = "Peggle Loot Results:",
    ["PEGGLELOOT_TITLE"] = "Peggle Loot Challenge",
    ["_PEGGLELOOT_WINNER"] = "*** Winner: %s ***",
    ["_PEGGLELOOT_WRONGMETHOD"] = "Peggle Loot requires the loot mode to be Master Looter.",
    ["PERSONAL_BEST"] = "PERSONAL BEST:",
    ["PERSONAL_BEST_PTS"] = "%s PTS",
    ["_PUBLISH_SCORE"] = "[Peggle]: %s just scored %s points on %s! Download the Peggle Addon for Wow to defeat their score!",
    ["_PUBLISH_DUEL_W"] = "[Peggle]: %s just defeated %s in a Peggle Duel! Download the Peggle Addon for Wow to pit your skills against them!",
    ["_PUBLISH_DUEL_L"] = "[Peggle]: %s was just defeated by %s in a Peggle Duel! Download the Peggle Addon for Wow to pit your skills against them!",
    ["_PUBLISH_1"] = CHAT_MSG_GUILD,
    ["_PUBLISH_2"] = CHAT_MSG_PARTY,
    ["_PUBLISH_3"] = CHAT_MSG_RAID,
    ["QUICK_PLAY"] = "QUICK PLAY",
    ["PLAYING"] = "Playing",
    ["_POINT_BOOST"] = "POINT BOOST!",
    ["_POINTS_LEFT"] = "Points left to spend",
    ["_RANK"] = "Rank (%d/%d)",
    ["_REQUIRES_5"] = "|cFFFF0000Requires 5 points in %s.\n",
    ["_REQUIRES_X"] = "|cFFFF0000Requires %d points in Peggle Talents.\n",
    ["SELECT_LEVEL"] = "SELECT A LEVEL",
    ["SCORE"] = "Score",
    ["SCORE_BEST"] = "Best",
    ["SCORE_TIME_LEFT"] = "Time Left: %s",
    ["SCORES"] = "SCORES",
    ["_SPECIAL_NAME1"] = "SUPER GUIDE",
    ["_SPECIAL_NAME2"] = "SPACE BLAST",
    ["_STYLE_COUNT"] = "+%s STYLE POINTS",
    ["_STYLESHOT_1"] = "FREE BALL SKILLS!\n+",
    ["_STYLESHOT_2"] = "LONG SHOT!\n+",
    ["_STYLESHOT_3"] = "SUPER LONG SHOT!\n+",
    ["_STYLESHOT_4"] = "MAD SKILLZ\n+",
    ["_STYLESHOT_4a"] = "CRAZY MAD SKILLZ\n+",
    ["_STYLESHOT_5"] = "EXTREME SLIDE!\n+",
    ["_STYLESHOT_6"] = "ORANGE ATTACK!\n+",
    ["_STYLESHOT_6a"] = "ORANGE ATTACK!\n+",
    ["_SUMMARY_TITLE0"] = "NO MORE SHOTS",
    ["_SUMMARY_TITLE1"] = "LEVEL COMPLETE",
    ["_SUMMARY_TITLE2"] = "LEVEL FULLY CLEARED",
    ["_SUMMARY_TITLE3"] = "LEVEL FINISHED",
    ["_SUMMARY_TITLE4"] = "BATTLE FINISHED",
    ["_SUMMARY_TITLE5"] = "LOOT SCORE SUBMITTED",
    ["SUMMARY_SCORE_BEST"] = "Best Score On This Level: |cFFFFFFFF%s",
    ["SUMMARY_SCORE_YOURS"] = "Score: |cFFFFFFFF%s",
    ["SUMMARY_STAT1"] = "Shots:",
    ["SUMMARY_STAT2"] = "Free Balls:",
    ["SUMMARY_STAT3"] = "% Cleared:",
    ["SUMMARY_STAT4"] = "Talent Score:",
    ["SUMMARY_STAT5"] = "Fever Score:",
    ["SUMMARY_STAT6"] = "Style Points:",
    ["_TALENT1_NAME"] = "TWO-SIDED COIN",
    ["_TALENT1_DESC"] = "Increases your chance of getting a free-ball when you don't hit any pegs by %d%%.",
    ["_TALENT2_NAME"] = "STYLE FOR MILES",
    ["_TALENT2_DESC"] = "Increases the points you receive for style shots by %d%%.",
    ["_TALENT3_NAME"] = "A STEP AHEAD",
    ["_TALENT3_DESC"] = "Your fever bonus meter starts with %d |4notch:notches; lit at the beginning of the match.",
    ["_TALENT4_NAME"] = "THE ONLY CURE",
    ["_TALENT4_DESC"] = "The points awarded by end of level Fever Buckets is increased by %d%%.",
    ["_TALENT5_NAME"] = "PEG MARKSMAN",
    ["_TALENT5_DESC"] = 'When you hit a peg, you have a %d%% chance to "crit" receiving 150%% of that peg\'s points.',
    ["_TALENT6_NAME"] = "MORE COWBELL",
    ["_TALENT6_DESC"] = "Purple pegs have a %d%% chance to increase your fever meter by 1.",
    ["_TALENT7_NAME"] = "MISSION CRITICAL",
    ["_TALENT7_DESC"] = "Your Crit pegs are worth %d%% of the original peg's value.",
    ["_TALENT8_NAME"] = "Unintended Awesome",
    ["_TALENT8_DESC"] = "When you hit a green peg, the purple peg has a %d%% chance of erupting in a small explosion, scoring itself and other nearby pegs.",
    ["_TALENT9_NAME"] = "Infusion of Awesome",
    ["_TALENT9_DESC"] = "Pegs hit with your special power have a %d%% chance to crit. (First two pegs hit with a guided ball OR all pegs hit with a space blast).",
    ["_TALENT10_NAME"] = "ROLLING IGNITION",
    ["_TALENT10_DESC"] = "When you hit a green peg and land the ball in the bucket in the same shot, one of your blue pegs is converted to a green peg.",
    ["_TALENT11_NAME"] = "DOUBLE FISSION",
    ["_TALENT11_DESC"] = "When you hit a purple peg, you score bonus points for each peg already hit in the shot as if you hit it again. These bonus points may not crit.",
    ["TALENTS"] = "TALENTS",
    ["TALENTS_DESC"] = "Talents are 'passive' abilities that affect all characters",
    ["_THE_ITEM"] = "the item",
    ["_TOOLTIP_MINIMAP"] = "Left-click to show/hide game.\nRight-click to move icon.",
    ["_TOOLTIP_MINIMAP2"] = "Left-click to show/hide game.\nRight-click for options.",
    ["_ACHIEVEMENT_EARNED"] = ACHIEVEMENT_UNLOCKED or "Achievement Earned",
    ["_TALENT_LEARN"] = TOOLTIP_TALENT_LEARN or "Click to learn",
    ["_TALENT_NEXT_RANK"] = TOOLTIP_TALENT_NEXT_RANK or "Next rank:",
    ["_TOTAL_MISS"] = "TOTAL MISS!",
    ["_TURNS"] = " TURNS",
    ["WIN_LOSS"] = "Win/Loss Record",
    ["WIN_LOSS_LEVEL"] = "(On this level)",
    ["WIN_LOSS_PLAYER"] = "W/L vs this opponent: %d - %d",
}
