/*<info serverAlias="DB042-bodb02" executers="" viewers="vnteam" isFunction="1"></info>*/
ALTER FUNCTION  [dbo].[f_age_settled_ticket_exclued_bettype]() 
RETURNS TABLE
AS
 /*
	Created	: 20180627@Patrick
	Task	: Sync settled ticket
	DB		: DB042.bodb02
*/

RETURN (
	select 1011 bettype--	Fishing World
	union all select 1031--	Max5D 60
	union all select 1032--	Max5D 90
	union all select 1033--	Max3D 60
	union all select 1034--	Max3D 90
	union all select 1035--	Max11x5 60
	union all select 1036--	Max11x5 90
	union all select 1037--	MaxDice 60
	union all select 1038--	MaxDice 90
	union all select 1503--	Slovakia
	union all select 1504--	Canada
	union all select 1505--	West Canada 
	union all select 1508--	Ohio
	union all select 1515--	Max Keno
	union all select 1516--	Max Keno 2
	union all select 1517--	Mini Keno
	union all select 1519--	Spring
	union all select 1520--	Summer 
	union all select 1521--	Autumn
	union all select 1522--	Winter
	union all select 1524--	Mini Keno 2
	union all select 1701--	Baccarat
	union all select 1702--	Roulette
	union all select 1800--	AG Casino - Deposit
	union all select 2008--	RNG Game *
	union all select 2009--	RNG Game
	union all select 2101--	Baccarat
	union all select 2102--	Battle War
	union all select 2103--	Blackjack
	union all select 2104--	Tri Card Poker
	union all select 2105--	Casino Hold'em
	union all select 2106--	Pai Gow Poker
	union all select 2108--	Roulette Pro
	union all select 2109--	Sic Bo
	union all select 2110--	Jacks or Better
	union all select 2113--	Baccarat Super 6
	union all select 2114--	Fish Prawn Crab
	union all select 2115--	Dragon Tiger
	union all select 2120--	Texas Hold'em
	union all select 2121--	Face Up 21
	union all select 2124--	Multi Wheel Roulette
	union all select 2129--	Turf King
	union all select 2130--	SpaKz
	union all select 2132--	Gong Xi Fa Chai
	union all select 2135--	Fruit Scratch
	union all select 2136--	Ho Ho Ho
	union all select 2144--	4-Line Jacks or Better
	union all select 2147--	Jungle Wild
	union all select 2148--	Engagement
	union all select 2149--	God of Prosperity
	union all select 2151--	Fox Force 5
	union all select 2152--	Journey to the West
	union all select 2153--	Winter Slot
	union all select 2154--	Western Zodiac
	union all select 2155--	Chinese Zodiac
	union all select 2156--	Water Margin
	union all select 2158--	Crazy Hospital
	union all select 2160--	Halloween
	union all select 2163--	Oriental Beauty
	union all select 2164--	Ninja Hero
	union all select 2165--	Tales of Brothel
	union all select 2166--	Fortune Gods
	union all select 2167--	Magician
	union all select 2173--	Dino Camp
	union all select 2174--	Tattoo Art
	union all select 2176--	Sea Orchestra
	union all select 2177--	Cash Out
	union all select 2178--	Baccarat(Progressive JP)
	union all select 2179--	Baccarat (Progressive JP) - Jackpot Game
	union all select 2198--	Jackpot Contribution
	union all select 2201--	(Mini) Baccarat
	union all select 2203--	(Mini) BlackJack
	union all select 2204--	(Mini) Jacks or Better
	union all select 2205--	(Mini) Sic Bo
	union all select 2206--	(Mini) Money Slot
	union all select 2301--	(Mobile)Baccarat
	union all select 2302--	(Mobile)Casino Hold' em
	union all select 2303--	(Mobile)Blackjack
	union all select 2304--	(Mobile)Jungle Wild
	union all select 2305--	(Mobile)God of Prosperity
	union all select 2306--	(Mobile)Sic Bo
	union all select 2307--	(Mobile)Oriental Beauty
	union all select 2308--	(Mobile)Magician
	union all select 2309--	(Mobile)Tales of Brothel
	union all select 2310--	(Mobile)Mini Roulette
	union all select 2311--	(Mobile)Baccarat Super 6
	union all select 2312--	(Mobile)Blackjack Perfect Pair
	union all select 2314--	(Mobile)Face Up 21
	union all select 2315--	(Mobile)Tri Card Poker
	union all select 2316--	(Mobile)Dragon Tiger
	union all select 2317--	(Mobile)Texas Hold'em
	union all select 2319--	(Mobile)Baccarat(Progressive JP)
	union all select 2320--	(Mobile)Baccarat (Progressive JP) - Jackpot Game
	union all select 2321--	(Mobile)Roulette Pro
	union all select 2398--	(Mobile)Jackpot Contribution
	union all select 2401--	Baccarat
	union all select 2402--	VIP Baccarat
	union all select 2403--	Roulette
	union all select 2404--	Sic Bo
	union all select 2405--	Dragon Tiger
	union all select 2502--	Special
	union all select 2503--	2D Head
	union all select 2504--	27 Sets
	union all select 2505--	27 Sets Live
	union all select 2506--	Special Not Drawn
	union all select 2507--	27 Sets - 4 Not Drawn
	union all select 2508--	27 Sets - 5 Not Drawn
	union all select 2509--	27 Sets - 6 Not Drawn
	union all select 2510--	27 Sets - 7 Not Drawn
	union all select 2511--	27 Sets - 8 Not Drawn
	union all select 2512--	PL2
	union all select 2513--	PL3
	union all select 2514--	PL4
	union all select 2515--	3D Head
	union all select 2516--	3D Tail
	union all select 2517--	3D - 23 Sets
	union all select 2518--	50 Sets
	union all select 2519--	25 Sets
	union all select 2520--	Sum Last
	union all select 2521--	Lunar
	union all select 2522--	Divide3
	union all select 2542--	2D Head
	union all select 2543--	2D Tail
	union all select 2544--	2D - 18 Sets
	union all select 2545--	2D - 7 Sets
	union all select 2546--	3D Head
	union all select 2547--	3D Tail
	union all select 2548--	3D - 17 Sets
	union all select 2549--	3D - 7 Sets
	union all select 2550--	PL2
	union all select 2551--	PL3
	union all select 2552--	PL4
	union all select 2582--	2D Head
	union all select 2583--	2D Tail
	union all select 2584--	2D - 18 Sets
	union all select 2585--	2D - 7 Sets
	union all select 2586--	3D Head
	union all select 2587--	3D Tail
	union all select 2588--	3D - 17 Sets
	union all select 2589--	3D - 7 Sets
	union all select 2590--	PL2
	union all select 2591--	PL3
	union all select 2592--	PL4
	union all select 2622--	2D Head
	union all select 2623--	2D Tail
	union all select 2624--	2D - 18 Sets
	union all select 2625--	2D - 7 Sets
	union all select 2626--	3D Head
	union all select 2627--	3D Tail
	union all select 2628--	3D - 17 Sets
	union all select 2629--	3D - 7 Sets
	union all select 2630--	PL2
	union all select 2631--	PL3
	union all select 2632--	PL4
	union all select 2681--	PL2
	union all select 2682--	PL3
	union all select 2683--	PL4
	union all select 2901--	(Tablet)Baccarat
	union all select 2902--	(Tablet)Casino Hold' em
	union all select 2903--	(Tablet)Blackjack
	union all select 2904--	(Tablet)Jungle Wild
	union all select 2905--	(Tablet)God of Prosperity
	union all select 2906--	(Tablet)Sic Bo
	union all select 2907--	(Tablet)Oriental Beauty
	union all select 2908--	(Tablet)Magician
	union all select 2909--	(Tablet)Tales of Brothel
	union all select 2910--	(Tablet)Mini Roulette
	union all select 2911--	(Tablet)Baccarat Super 6
	union all select 2913--	(Tablet)Face Up 21
	union all select 2914--	(Tablet)Tri Card Poker
	union all select 2915--	(Tablet)Dragon Tiger
	union all select 2916--	(Tablet)Texas Hold'em
	union all select 2919--	(Tablet)Baccarat(Progressive JP)
	union all select 2920--	(Tablet)Baccarat (Progressive JP) - Jackpot Game
	union all select 2921--	(Tablet)Roulette Pro
	union all select 2998--	(Tablet)Jackpot Contribution
	union all select 4002--	Big Haul
	union all select 4003--	Bushido Code
	union all select 4004--	Casino Stud Poker
	union all select 4005--	Catch the Waves
	union all select 4008--	Dancing Lions
	union all select 4009--	Dragon King
	union all select 4010--	Dragons and Pearls
	union all select 4011--	Fish 'O' Mania
	union all select 4012--	Fortune Panda
	union all select 4013--	God of Wealth
	union all select 4014--	Gold of Ra
	union all select 4015--	Guardian Lion
	union all select 4018--	King of Time
	union all select 4019--	Lady Luck
	union all select 4020--	Mystic Riches
	union all select 4021--	Phoenix Princess
	union all select 4022--	Roulette
	union all select 4023--	Temple Treasures
	union all select 4024--	Thai Dragon
	union all select 4025--	Treasure Reef
	union all select 4026--	Venetia
	union all select 4028--	Wild Dolphin
	union all select 4029--	Wolf Quest
	union all select 4101--	888 Dragons™
	union all select 4102--	Triple Tigers™
	union all select 4103--	Diamonds are Forever 3 Lines
	union all select 4104--	Gold Train™
	union all select 4105--	888 Gold™
	union all select 4106--	7 Piggies™
	union all select 4107--	7 Monkeys
	union all select 4108--	Monkey Madness™
	union all select 4109--	Diamond Strike™
	union all select 4110--	Fairytale Fortune™
	union all select 4111--	8 Dragons™
	union all select 4112--	Lady Godiva
	union all select 4113--	Journey to the West
	union all select 4114--	Wolf Gold™
	union all select 4115--	Dragon Kingdom
	union all select 4116--	Hot Safari
	union all select 4117--	3 Kingdoms - Battle of Red Cliffs
	union all select 4118--	Chilli Heat
	union all select 4119--	Caishen’s Gold™
	union all select 4120--	Pixie Wings™
	union all select 4121--	Aztec Gems
	union all select 4122--	Lucky New Year
	union all select 18000--	Colossus Bets

	--union all select 10--	outright
)
GO