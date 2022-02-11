/*<info serverAlias="DBTXN-bodb02,DBPRO-bodb02" executers="" viewers="" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_Set_GetGroupBettypes] ()
RETURNS TABLE
WITH SCHEMABINDING
AS

/*
    Created: 
    Task: 
    DB: DBTXN/bodb02; DBPRO/bodb02
    Revisions:
		- 20160825@Bobby: #62921 - Allow FGLG (14,127) bet types to settle determindable
		- 20160920@Kent: Add logic for grouping bettypes [Redmine:#63202]
		- 20161025@Kathy: Add FastMarket [Redmine:#56367]
		- 20161118@Bobby: #67462 - Implement SDT for Over/Under bettypes full winlost
		- 20170215@Kathy: Basketball All-in-One [Redmine:#71372]
		- 20170609@Kathy: Set IsAuto = 1 for some "early settled" bettypes of BAIO (604, 606, 607, 613) [Redmine:#77835]
		- 20170918@Kent: Add New Bettypes Decimal Only 461, 462, 463, 464 [Redmine:#83255]
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
		- 20171211@Kathy: Do not calculate bettype 22 with old format (betteam:h,a) [Redmine:#80947]
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
		- 20180301@Benjamin: Add Bettype: 226,227 - Fast Markets Phase 2 [Redmine:#90667]
		- 20180419@Benjamin: Adding 2 New Bet Types: 465,466 for Asian 1x2 [Redmine:#93654]
		- 20180816@Alan: Incorporate ESports 2.0 [99448]
		- 20190222@Sol: New Formula for Comm [109007]
		- 20190527@Sol: Incorporate PHAIO 4 [Redmine:#112885]
		- 20190620@Sol: Incorporate PHAIO 4b - 27 Corners Bet Types [Redmine:#115232]
		- 20190718@Sol: Relocate bettype 22 From early settlement to Main settlement [Redmine:#115232]
		- 20190923@Tiara: BMAIO - Badminton All In One [Redmine #120324]
		- 20191112@Sol: Incorporate PHAIO 5 [Redmine:#121681]
		- 20200507@Kathy: Add new bettype for E-Sports [#132401]
		- 20200428@Kathy: PHAIO 5 - Add new penalty bettype[Redmine:#132805]
		- 20200710@Kathy: Incorporate New Bet Types of Basketball - Phase 2 [Redmine:#135846]
		- 20200928@Helen: Implement New Bettype 228 Time Machine Over/Under [Redmine:#142001]
		- 20201123@Kathy: Apply Settlement by Profile for soccer [Redmine:#142425]
		- 20210122@Louisa: Cricket AIO [Redmine:#148870]
		- 20210406@Kathy: New bettype 229 [Readmine:#152748]
		- 20210521@Louisa: Cricket AIO - Phase 1.2 [Redmine:#154811]
		- 20210107@Louisa: E-Sports Phase 4 [Redmine:#166330]
		- 20220128@Louisa: Cricket AIO Phase 2 [Redmine:#166335]		
	
    Parameters Explanation:    
    
    - GroupId: 1 - HT
               2 - FT
               3 - HT-FGLG
               4 - FT-FGLG
               5 - HT-Corner
               6 - FT-Corner
               7 - Tennis
               8 - Auto-BetRadar
               9 - FastMarket
			   10 - new bettypes of Basketball
			   11 - E-Sports 2.0
			   12 - Cricket AIO
			
	- CommBettypeGroupId: 1 - Major group

	- DeterminedType: (from right to left) value will be 1 or 2 or 3
		+ Bit 1 - HT - Refund All
		+ Bit 2 - FT - Refund Fulltime
*/

RETURN (
    --HT
	SELECT	CONVERT(SMALLINT, 1) AS GroupId
			, CONVERT(SMALLINT, 7) AS BetType
			, CONVERT(BIT, 0) AS IsDetermined
			, CONVERT(BIT, 0) AS IsUsedGoalRecordValue
			, CONVERT(BIT, 1) AS Is3x30
			, CONVERT(BIT,0) AS IsAuto
			, CONVERT(VARCHAR(50), '1H') AS GroupName
			, CONVERT(TINYINT, 0) AS DeterminedType
			, CONVERT(BIT,0) AS IsFGLG
			, CONVERT(SMALLINT, 1) AS CommBettypeGroupId
			, CONVERT(SMALLINT, 1) AS SettledByProfile
	UNION ALL SELECT 1,    8  ,  1, 0, 1, 0, '1H', 1, 0,1,1
	UNION ALL SELECT 1,    12  ,  0, 0, 1, 0, '1H', 0, 0,1,1
	UNION ALL SELECT 1,    15  ,  0, 0, 1, 0, '1H', 0, 0,0,1
	UNION ALL SELECT 1,    21  ,  0, 0, 1, 0, '1H', 0, 0,0,0
	UNION ALL SELECT 1,    30  ,  1, 0, 1, 0, '1H', 1, 0,0,0
	UNION ALL SELECT 1,    125  ,  0, 0, 1, 0, '1H', 0, 0,0,0
	UNION ALL SELECT 1,    126  ,  1, 0, 1, 0, '1H', 1, 0,0,1
	UNION ALL SELECT 1,    129  ,  1, 0, 1, 0, '1H', 1, 0,0,0
	UNION ALL SELECT 1,    136  ,  0, 0, 1, 0, '1H', 0, 0,1,0
	UNION ALL SELECT 1,    138  ,  0, 0, 1, 0, '1H', 0, 0,1,0
	UNION ALL SELECT 1,    143  ,  1, 0, 1, 0, '1H', 1, 0,0,0
	UNION ALL SELECT 1,    151  ,  0, 0, 1, 0, '1H', 0, 0,0,0
	UNION ALL SELECT 1,    165  ,  0, 0, 1, 0, '1H', 0, 0,0,0
	UNION ALL SELECT 1,    167  ,  0, 0, 1, 0, '1H', 0, 0,0,0
	UNION ALL SELECT 1,    179  ,  1, 0, 1, 0, '1H', 1, 0,0,0
	UNION ALL SELECT 1,    181  ,  1, 0, 1, 0, '1H', 1, 0,0,0
	UNION ALL SELECT 1,    182  ,  1, 0, 1, 0, '1H', 1, 0,0,0
	UNION ALL SELECT 1,    188  ,  1, 0, 1, 0, '1H', 1, 0,0,0
	UNION ALL SELECT 1,    191  ,  0, 0, 1, 0, '1H', 0, 0,0,0
	UNION ALL SELECT 1,    303  ,  0, 0, 1, 0, '1H', 0, 0,0,0
	UNION ALL SELECT 1,    304  ,  1, 0, 1, 0, '1H', 1, 0,0,0
	UNION ALL SELECT 1,    403  ,  1, 0, 1, 0, '1H', 1, 0,1,0
	UNION ALL SELECT 1,    463  ,  1, 0, 1, 0, '1H', 1, 0,1,0
	UNION ALL SELECT 1,    404  ,  1, 0, 1, 0, '1H', 1, 0,1,0
	UNION ALL SELECT 1,    464  ,  1, 0, 1, 0, '1H', 1, 0,1,0
	UNION ALL SELECT 1,    410  ,  0, 0, 1, 0, '1H', 0, 0,0,0
	UNION ALL SELECT 1,    411  ,  0, 0, 1, 0, '1H', 0, 0,0,0
	UNION ALL SELECT 1,    412  ,  1, 0, 1, 0, '1H', 1, 0,0,1
	UNION ALL SELECT 1,    414  ,  1, 0, 1, 0, '1H', 1, 0,0,1
	UNION ALL SELECT 1,    426  ,  1, 0, 1, 0, '1H', 1, 0,0,0
	UNION ALL SELECT 1,    427  ,  1, 0, 1, 0, '1H', 1, 0,0,0
	UNION ALL SELECT 1,    606  ,  0, 0, 0, 1, '1H', 0, 0,0,0 -- Basketball
	UNION ALL SELECT 1,    608  ,  0, 0, 0, 0, '1H', 0, 0,0,0 -- Basketball
	UNION ALL SELECT 1,    621  ,  0, 0, 0, 0, '1H', 0, 0,0,0-- Basketball
	UNION ALL SELECT 1,    622  ,  0, 0, 0, 0, '1H', 0, 0,0,0 -- Basketball
	UNION ALL SELECT 1,    623  ,  0, 0, 0, 0, '1H', 0, 0,0,0 -- Basketball
	UNION ALL SELECT 1,    633  ,  0, 0, 0, 0, '1H', 0, 0,0,0 -- Basketball
	--End HT
	 
	--FT
	UNION ALL SELECT 2,    1  ,  0, 0, 0, 0, 'FT', 0, 0,1,1
	UNION ALL SELECT 2,    2  ,  0, 0, 0, 0, 'FT', 0, 0,1,1
	UNION ALL SELECT 2,    3  ,  1, 0, 0, 0, 'FT', 3, 0,1,1
	UNION ALL SELECT 2,    4  ,  1, 0, 0, 0, 'FT', 3, 0,0,1
	UNION ALL SELECT 2,    5  ,  0, 0, 0, 0, 'FT', 0, 0,0,1
	UNION ALL SELECT 2,    6  ,  1, 0, 0, 0, 'FT', 3, 0,0,1
	UNION ALL SELECT 2,    13  ,  1, 0, 0, 0, 'FT', 3, 0,0,1
	UNION ALL SELECT 2,    16  ,  1, 0, 1, 0, 'FT', 3, 0,0,1
	UNION ALL SELECT 2,    17  ,  0, 0, 1, 0, '2H', 0, 0,1,0
	UNION ALL SELECT 2,    18  ,  1, 0, 1, 0, '2H', 2, 0,1,0
	UNION ALL SELECT 2,    20  ,  0, 0, 0, 0, 'FT', 0, 0,0,0
	
	UNION ALL SELECT 2,    24  ,  0, 0, 0, 0, 'FT', 0, 0,0,0
	UNION ALL SELECT 2,    25  ,  0, 0, 0, 0, 'FT', 0, 0,0,0
	UNION ALL SELECT 2,    26  ,  1, 0, 0, 0, 'FT', 3, 0,0,0
	UNION ALL SELECT 2,    27  ,  1, 0, 0, 0, 'FT', 3, 0,0,0
	UNION ALL SELECT 2,    28  ,  0, 0, 0, 0, 'FT', 0, 0,0,0
	UNION ALL SELECT 2,    121  ,  0, 0, 0, 0, 'FT', 0, 0,0,0
	UNION ALL SELECT 2,    122  ,  0, 0, 0, 0, 'FT', 0, 0,0,0
	UNION ALL SELECT 2,    123  ,  0, 0, 0, 0, 'FT', 0, 0,0,0
	UNION ALL SELECT 2,    124  ,  0, 0, 0, 0, 'FT', 0, 0,0,0
	UNION ALL SELECT 2,    128  ,  1, 0, 1, 0, 'FT', 2, 0,0,0
	UNION ALL SELECT 2,    130  ,  1, 0, 0, 0, 'FT', 3, 0,0,0
	UNION ALL SELECT 2,    131  ,  1, 0, 0, 0, 'FT', 3, 0,0,0
	UNION ALL SELECT 2,    132  ,  1, 0, 0, 0, 'FT', 3, 0,0,0
	UNION ALL SELECT 2,    133  ,  1, 0, 1, 0, 'FT', 2, 0,0,0
	UNION ALL SELECT 2,    134  ,  1, 0, 1, 0, 'FT', 2, 0,0,0
	UNION ALL SELECT 2,    137  ,  0, 0, 0, 0, 'FT', 0, 0,1,0
	UNION ALL SELECT 2,    139  ,  0, 0, 0, 0, 'FT', 0, 0,1,0
	UNION ALL SELECT 2,    140  ,  1, 0, 1, 0, 'FT', 2, 0,0,0
	UNION ALL SELECT 2,    141  ,  1, 0, 1, 0, 'FT', 2, 0,0,0
	UNION ALL SELECT 2,    142  ,  1, 0, 1, 0, 'FT', 2, 0,0,0
	UNION ALL SELECT 2,    144  ,  1, 0, 0, 0, 'FT', 3, 0,0,0
	UNION ALL SELECT 2,    145  ,  1, 0, 0, 0, 'FT', 3, 0,0,0
	UNION ALL SELECT 2,    146  ,  1, 0, 1, 0, '2H', 2, 0,0,0
	UNION ALL SELECT 2,    147  ,  1, 0, 1, 0, 'FT', 2, 0,0,0
	UNION ALL SELECT 2,    148  ,  1, 0, 1, 0, 'FT', 2, 0,0,0
	UNION ALL SELECT 2,    149  ,  1, 0, 1, 0, 'FT', 2, 0,0,0
	UNION ALL SELECT 2,    150  ,  1, 0, 1, 0, 'FT', 2, 0,0,0
	UNION ALL SELECT 2,    152  ,  1, 0, 1, 0, 'FT', 3, 0,0,0
	UNION ALL SELECT 2,    157  ,  0, 0, 0, 0, 'FT', 0, 0,0,0
	UNION ALL SELECT 2,    159  ,  1, 0, 0, 0, 'FT', 3, 0,0,0
	UNION ALL SELECT 2,    161  ,  1, 0, 0, 0, 'FT', 3, 0,0,0
	UNION ALL SELECT 2,    162  ,  1, 0, 0, 0, 'FT', 3, 0,0,0
	UNION ALL SELECT 2,    163  ,  1, 0, 0, 0, 'FT', 3, 0,0,0
	UNION ALL SELECT 2,    166  ,  0, 0, 0, 0, 'FT', 0, 0,0,0
	UNION ALL SELECT 2,    170  ,  1, 0, 0, 0, 'FT', 3, 0,0,0
	UNION ALL SELECT 2,    171  ,  0, 0, 0, 0, 'FT', 0, 0,0,0
	UNION ALL SELECT 2,    172  ,  1, 1, 0, 0, 'FT', 3, 1,0,0
	UNION ALL SELECT 2,    177  ,  0, 0, 1, 0, '2H', 0, 0,0,0
	UNION ALL SELECT 2,    178  ,  1, 0, 1, 0, '2H', 2, 0,0,0
	UNION ALL SELECT 2,    183  ,  0, 0, 1, 0, '2H', 0, 0,0,0
	UNION ALL SELECT 2,    184  ,  0, 0, 1, 0, '2H', 0, 0,0,0
	UNION ALL SELECT 2,    185  ,  0, 0, 1, 0, '2H', 0, 0,0,0
	UNION ALL SELECT 2,    186  ,  0, 0, 1, 0, '2H', 0, 0,0,0
	UNION ALL SELECT 2,    187  ,  1, 0, 1, 0, '2H', 2, 0,0,0
	UNION ALL SELECT 2,    189  ,  1, 0, 1, 0, 'FT', 2, 0,0,0
	UNION ALL SELECT 2,    190  ,  1, 0, 1, 0, 'FT', 3, 0,0,0
	UNION ALL SELECT 2,    301  ,  0, 0, 0, 0, 'FT', 0, 0,0,0
	UNION ALL SELECT 2,    302  ,  1, 0, 0, 0, 'FT', 3, 0,0,0
	UNION ALL SELECT 2,    401  ,  1, 0, 0, 0, 'FT', 3, 0,1,0
	UNION ALL SELECT 2,    461  ,  1, 0, 0, 0, 'FT', 3, 0,1,0
	UNION ALL SELECT 2,    402  ,  1, 0, 0, 0, 'FT', 3, 0,1,0
	UNION ALL SELECT 2,    462  ,  1, 0, 0, 0, 'FT', 3, 0,1,0
	UNION ALL SELECT 2,    405  ,  1, 0, 1, 0, '2H', 2, 0,0,1
	UNION ALL SELECT 2,    406  ,  1, 0, 0, 0, 'FT', 3, 0,0,1
	UNION ALL SELECT 2,    407  ,  1, 0, 0, 0, 'FT', 3, 0,0,1
	UNION ALL SELECT 2,    408  ,  1, 0, 0, 0, 'FT', 3, 0,0,1
	UNION ALL SELECT 2,    409  ,  1, 0, 0, 0, 'FT', 3, 0,0,0
	UNION ALL SELECT 2,    413  ,  1, 0, 0, 0, 'FT', 3, 0,0,1
	UNION ALL SELECT 2,    415  ,  1, 1, 0, 0, 'FT', 3, 1,0,0
	UNION ALL SELECT 2,    416  ,  1, 0, 1, 0, 'FT', 3, 0,0,1
	UNION ALL SELECT 2,    417  ,  1, 0, 0, 0, 'FT', 3, 0,0,0
	UNION ALL SELECT 2,    418  ,  1, 0, 0, 0, 'FT', 3, 0,0,0
	UNION ALL SELECT 2,    419  ,  1, 0, 1, 0, 'FT', 3, 0,0,0
	UNION ALL SELECT 2,    420  ,  1, 0, 1, 0, 'FT', 3, 0,0,0
	UNION ALL SELECT 2,    421  ,  1, 0, 1, 0, 'FT', 3, 0,0,0
	UNION ALL SELECT 2,    422  ,  1, 1, 0, 0, 'FT', 3, 0,0,0
	UNION ALL SELECT 2,    423  ,  1, 1, 0, 0, 'FT', 3, 0,0,0
	UNION ALL SELECT 2,    425  ,  0, 1, 0, 0, 'FT', 0, 0,0,0
	UNION ALL SELECT 2,    428  ,  0, 0, 1, 0, '2H', 0, 0,1,0
	UNION ALL SELECT 2,    429  ,  1, 0, 1, 0, '2H', 2, 0,0,0
	UNION ALL SELECT 2,    430  ,  0, 0, 1, 0, '2H', 0, 0,0,0
	UNION ALL SELECT 2,    431  ,  0, 0, 1, 0, '2H', 0, 0,0,0
	UNION ALL SELECT 2,    432  ,  0, 0, 1, 0, '2H', 0, 0,0,0
	UNION ALL SELECT 2,    433  ,  1, 0, 1, 0, '2H', 2, 0,0,0
	UNION ALL SELECT 2,    434  ,  1, 0, 1, 0, 'FT', 2, 0,0,0
	UNION ALL SELECT 2,    435  ,  1, 0, 1, 0, 'FT', 3, 0,0,0
	UNION ALL SELECT 2,    436  ,  1, 0, 1, 0, 'FT', 2, 0,0,0
	UNION ALL SELECT 2,    437  ,  1, 0, 1, 0, 'FT', 2, 0,0,0
	UNION ALL SELECT 2,    438  ,  1, 0, 1, 0, 'FT', 2, 0,0,0
	UNION ALL SELECT 2,    439  ,  1, 0, 1, 0, 'FT', 2, 0,0,0
	UNION ALL SELECT 2,    440  ,  1, 0, 1, 0, 'FT', 2, 0,0,0
	UNION ALL SELECT 2,    441  ,  1, 0, 1, 0, 'FT', 2, 0,0,0
	UNION ALL SELECT 2,    442  ,  1, 0, 1, 0, 'FT', 2, 0,0,0
	UNION ALL SELECT 2,    443  ,  1, 0, 1, 0, 'FT', 2, 0,0,0
	UNION ALL SELECT 2,    444  ,  1, 0, 1, 0, 'FT', 2, 0,0,0
	UNION ALL SELECT 2,    445  ,  1, 0, 1, 0, 'FT', 3, 0,0,0
	UNION ALL SELECT 2,    446  ,  1, 0, 1, 0, 'FT', 3, 0,0,0
	UNION ALL SELECT 2,    447  ,  1, 0, 1, 0, 'FT', 3, 0,0,0
	UNION ALL SELECT 2,    501  ,  0, 0, 0, 0, 'FT', 0, 0,0,0
	UNION ALL SELECT 2,    601  ,  0, 0, 0, 0, 'FT', 0, 0,0,0 -- Basketball
	UNION ALL SELECT 2,    602  ,  0, 0, 0, 0, 'FT', 0, 0,0,0 -- Basketball
	UNION ALL SELECT 2,    603  ,  0, 0, 0, 0, 'FT', 0, 0,0,0 -- Basketball
	UNION ALL SELECT 2,    604  ,  0, 0, 0, 1, 'FT', 0, 0,0,0-- Basketball
	UNION ALL SELECT 2,    605  ,  0, 0, 0, 0, 'FT', 0, 0,0,0-- Basketball
	UNION ALL SELECT 2,    607  ,  0, 0, 0, 1, '2H', 0, 0,0,0-- Basketball
	UNION ALL SELECT 2,    618  ,  0, 0, 0, 0, 'FT', 0, 0,0,0-- Basketball
	UNION ALL SELECT 2,    619  ,  0, 0, 0, 0, 'FT', 0, 0,0,0-- Basketball
	UNION ALL SELECT 2,    620  ,  0, 0, 0, 0, 'FT', 0, 0,0,0-- Basketball
	UNION ALL SELECT 2,    624  ,  0, 0, 0, 0, '2H', 0, 0,0,0-- Basketball
	UNION ALL SELECT 2,    625  ,  0, 0, 0, 0, '2H', 0, 0,0,0-- Basketball
	UNION ALL SELECT 2,    626  ,  0, 0, 0, 0, '2H', 0, 0,0,0-- Basketball
	UNION ALL SELECT 2,    634  ,  0, 0, 0, 0, '2H', 0, 0,0,0-- Basketball
	UNION ALL SELECT 2,    632  ,  0, 0, 0, 0, 'FT', 0, 0,0,0-- Basketball
	UNION ALL SELECT 2,    635  ,  0, 0, 0, 0, 'FT', 0, 0,0,0-- Basketball
	UNION ALL SELECT 2,    636  ,  0, 0, 0, 0, 'FT', 0, 0,0,0-- Basketball
	UNION ALL SELECT 2,    637  ,  0, 0, 0, 0, 'FT', 0, 0,0,0-- Basketball
	UNION ALL SELECT 2,    638  ,  0, 0, 0, 0, 'FT', 0, 0,0,0-- Basketball
	UNION ALL SELECT 2,    639  ,  0, 0, 0, 0, 'FT', 0, 0,0,0-- Basketball
	UNION ALL SELECT 2,    640  ,  0, 0, 0, 0, 'FT', 0, 0,0,0-- Basketball
	UNION ALL SELECT 2,    641  ,  0, 0, 0, 0, 'FT', 0, 0,0,0-- Basketball
	UNION ALL SELECT 2,    642  ,  0, 0, 0, 0, 'FT', 0, 0,0,0-- Basketball
	UNION ALL SELECT 2,    643  ,  0, 0, 0, 0, 'FT', 0, 0,0,0-- Basketball
	UNION ALL SELECT 2,    644  ,  0, 0, 0, 0, 'FT', 0, 0,0,0-- Basketball
	UNION ALL SELECT 2,    645  ,  0, 0, 0, 0, 'FT', 0, 0,0,0-- Basketball
	UNION ALL SELECT 2,    646 ,  0, 0, 0, 0, 'FT', 0, 0,0 ,0-- Basketball
														   
	--End FT
	 
	--HT-FGLG
	UNION ALL SELECT 3,    127  ,  1, 1, 1, 0, '1H', 1, 1,0,0
	--End HT-FGLG
	 
	--FT-FGLG
	UNION ALL SELECT 4,    14  ,  1, 1, 0, 0, 'FT', 3, 1,0,0
	--End FT-FGLG
	 
	--HT-Corner
	UNION ALL SELECT 5,    200  ,  1, 0, 1, 0, '1H', 1, 0,0,0
	UNION ALL SELECT 5,    201  ,  1, 0, 1, 0, '1H', 1, 0,0,0
	UNION ALL SELECT 5,    202  ,  1, 0, 1, 0, '1H', 1, 0,0,0
	UNION ALL SELECT 5,    203  ,  0, 0, 1, 0, '1H', 0, 0,0,0
	UNION ALL SELECT 5,    204  ,  1, 0, 1, 0, '1H', 1, 0,0,0
	UNION ALL SELECT 5,    205  ,  1, 0, 1, 0, '1H', 1, 0,0,0
	UNION ALL SELECT 5,    207  ,  1, 0, 1, 0, '1H', 1, 0,0,0
	UNION ALL SELECT 5,    209  ,  0, 0, 1, 0, '1H', 0, 0,0,0
	--End HT-Corner										  
	 													   
	--FT-Corner											   
	UNION ALL SELECT 6,    194  ,  0, 0, 0, 0, 'FT', 0, 0,0,0
	UNION ALL SELECT 6,    195  ,  1, 0, 0, 0, 'FT', 3, 0,0,0
	UNION ALL SELECT 6,    196  ,  1, 0, 0, 0, 'FT', 3, 0,0,0
	UNION ALL SELECT 6,    197  ,  1, 0, 0, 0, 'FT', 3, 0,0,0
	UNION ALL SELECT 6,    198  ,  1, 0, 0, 0, 'FT', 3, 0,0,0
	UNION ALL SELECT 6,    199  ,  1, 0, 0, 0, 'FT', 3, 0,0,0
	UNION ALL SELECT 6,    206  ,  1, 0, 0, 0, 'FT', 3, 0,0,0
	UNION ALL SELECT 6,    208  ,  0, 0, 0, 0, 'FT', 0, 0,0,0
	--End FT-Corner										   
	 													   
	--Tennis											   
	UNION ALL SELECT 7,    153  ,  0, 0, 0, 0, 'FT', 0, 0,1,0
	UNION ALL SELECT 7,    154  ,  0, 0, 0, 0, 'FT', 0, 0,0,0
	UNION ALL SELECT 7,    155  ,  0, 0, 0, 0, 'FT', 0, 0,1,0
	UNION ALL SELECT 7,    156  ,  0, 0, 0, 0, 'FT', 0, 0,1,0
	UNION ALL SELECT 7,    1301  ,  0, 0, 0, 0, 'FT', 0, 0,0,0
	UNION ALL SELECT 7,    1302  ,  0, 0, 0, 0, 'FT', 0, 0,0,0
	UNION ALL SELECT 7,    1303  ,  0, 0, 0, 0, 'FT', 0, 0,0,0
	UNION ALL SELECT 7,    1305  ,  0, 0, 0, 0, 'FT', 0, 0,0,0
	UNION ALL SELECT 7,    1306  ,  0, 0, 0, 0, 'FT', 0, 0,0,0
	UNION ALL SELECT 7,    1308  ,  0, 0, 0, 0, 'FT', 0, 0,0,0
	UNION ALL SELECT 7,    1311  ,  0, 0, 0, 0, 'FT', 0, 0,0,0
	UNION ALL SELECT 7,    1312  ,  0, 0, 0, 0, 'FT', 0, 0,0,0
	UNION ALL SELECT 7,    1316  ,  0, 0, 0, 0, 'FT', 0, 0,0,0
	UNION ALL SELECT 7,    1317  ,  0, 0, 0, 0, 'FT', 0, 0,0,0
	UNION ALL SELECT 7,    1318  ,  0, 0, 0, 0, 'FT', 0, 0,0,0
	UNION ALL SELECT 7,    1324  ,  1, 0, 0, 0, 'FT', 1, 0,0,0
	--End Tennis
	 
	--BetRadar
	UNION ALL SELECT 8,    424  ,  0, 0, 0, 1, 'FT', 0, 0,0,0
	
	-- Fast Market
	UNION ALL SELECT 9,    221  ,  0, 0, 0, 1, 'Special', 0, 0,0,0
	UNION ALL SELECT 9,    222  ,  0, 0, 0, 1, 'Special', 0, 0,0,0
	UNION ALL SELECT 9,    223  ,  0, 0, 0, 1, 'Special', 0, 0,0,0
	UNION ALL SELECT 9,    224  ,  0, 0, 0, 1, 'Special', 0, 0,0,0
	UNION ALL SELECT 9,    225  ,  0, 0, 0, 1, 'Special', 0, 0,0,0
	UNION ALL SELECT 9,    226  ,  0, 0, 0, 1, 'Special', 0, 0,0,0
	UNION ALL SELECT 9,    227  ,  0, 0, 0, 1, 'Special', 0, 0,0,0
	UNION ALL SELECT 9,    228  ,  0, 0, 0, 1, 'Special', 0, 0,0,0
	UNION ALL SELECT 9,    229  ,  0, 0, 0, 1, 'Special', 0, 0,0,0
																
	-- new bettypes of Basketball								
	UNION ALL SELECT 10,   609  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
	UNION ALL SELECT 10,   610  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
	UNION ALL SELECT 10,   611  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
	UNION ALL SELECT 10,   612  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 10,   613  ,  0, 0, 0, 1, 'Special', 0, 0,0,0
	UNION ALL SELECT 10,   614  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 10,   615  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
	UNION ALL SELECT 10,   616  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
	UNION ALL SELECT 10,   617  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 10,   627  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 10,   628  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 10,   629  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 10,   630  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 10,   631  ,  0, 0, 0, 0, 'Special', 0, 0,0,0

	-- E-Sports 2.0
	UNION ALL SELECT 11,   9001  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9002  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
    UNION ALL SELECT 11,   9003  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
    UNION ALL SELECT 11,   9004  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9005  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
    UNION ALL SELECT 11,   9006  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9007  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9008  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
    UNION ALL SELECT 11,   9009  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
    UNION ALL SELECT 11,   9010  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9011  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9012  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
    UNION ALL SELECT 11,   9013  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
    UNION ALL SELECT 11,   9014  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9015  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9016  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9017  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9018  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
    UNION ALL SELECT 11,   9019  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
    UNION ALL SELECT 11,   9020  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9021  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9022  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9023  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9024  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
    UNION ALL SELECT 11,   9025  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
    UNION ALL SELECT 11,   9026  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9027  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9028  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
    UNION ALL SELECT 11,   9029  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
    UNION ALL SELECT 11,   9030  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9031  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9032  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9033  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9034  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
    UNION ALL SELECT 11,   9035  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
    UNION ALL SELECT 11,   9036  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9037  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9038  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9039  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9040  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
    UNION ALL SELECT 11,   9041  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
    UNION ALL SELECT 11,   9042  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9043  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9044  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9045  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9046  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
    UNION ALL SELECT 11,   9047  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
    UNION ALL SELECT 11,   9048  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9049  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9050  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9051  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9052  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
    UNION ALL SELECT 11,   9053  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
    UNION ALL SELECT 11,   9054  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9055  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9056  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9057  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9058  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
    UNION ALL SELECT 11,   9059  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
    UNION ALL SELECT 11,   9060  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
    UNION ALL SELECT 11,   9061  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
    UNION ALL SELECT 11,   9062  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9063  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9064  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9065  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9066  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9067  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9068  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9069  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9070  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
    UNION ALL SELECT 11,   9071  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
    UNION ALL SELECT 11,   9072  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9073  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
    UNION ALL SELECT 11,   9074  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
	UNION ALL SELECT 11,   9075  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9076  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
	UNION ALL SELECT 11,   9077  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
	UNION ALL SELECT 11,   9078  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
	UNION ALL SELECT 11,   9079  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
	UNION ALL SELECT 11,   9080  ,  0, 0, 0, 0, 'Special', 0, 0,1,0 
	UNION ALL SELECT 11,   9081  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
	UNION ALL SELECT 11,   9082  ,  0, 0, 0, 0, 'Special', 0, 0,1,0 
	UNION ALL SELECT 11,   9083  ,  0, 0, 0, 0, 'Special', 0, 0,1,0 
	UNION ALL SELECT 11,   9084  ,  0, 0, 0, 0, 'Special', 0, 0,1,0 
	UNION ALL SELECT 11,   9085  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
	UNION ALL SELECT 11,   9086  ,  0, 0, 0, 0, 'Special', 0, 0,1,0
	
	-- E-Sports 3.0
	UNION ALL SELECT 11,   9087  ,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 2,   9088  ,  0, 0, 0, 0, 'FT', 0, 0,0,0

		--ESports Phase 4
	UNION ALL SELECT 11,   9089,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9090,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9091,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9092,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9093,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9094,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9095,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9096,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9097,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9098,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9099,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9100,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9101,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9102,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9103,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9104,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9105,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9106,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9107,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9108,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9109,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9110,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9111,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9112,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9113,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9114,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9115,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9116,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9117,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9118,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9119,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9120,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9121,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9122,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9123,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9124,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9125,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9126,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9127,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9128,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9129,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9130,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9131,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9132,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9133,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9134,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9135,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9136,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9137,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9138,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9139,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9140,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9141,  0, 0, 0, 0, 'Special', 0, 0,0,0
	UNION ALL SELECT 11,   9142,  0, 0, 0, 0, 'Special', 0, 0,0,0

	-- new bettypes of PHAIO Phase 3
	UNION ALL SELECT 2,448,1,1,0,0,'FT',3, 1,0,0
	UNION ALL SELECT 2,449,1,0,0,0,'FT',3, 0,0,0
	UNION ALL SELECT 2,450,1,0,0,0,'FT',3, 0,1,0
	UNION ALL SELECT 2,451,1,0,0,0,'FT',3, 0,0,0
	UNION ALL SELECT 2,452,1,0,1,0,'FT',2, 0,0,0
	UNION ALL SELECT 1,453,0,0,1,0,'1H',0, 0,0,0
	UNION ALL SELECT 2,454,1,1,0,0,'FT',3, 1,0,0
	UNION ALL SELECT 8,455,0,0,0,1,'FT',0, 0,0,0
	UNION ALL SELECT 1,456,1,0,1,0,'1H',1, 0,0,0
	UNION ALL SELECT 1,457,1,0,1,0,'1H',1, 0,0,0
	UNION ALL SELECT 2,458,0,0,0,0,'FT',0, 0,0,0
	UNION ALL SELECT 1,459,0,0,1,0,'1H',0, 0,0,0
	UNION ALL SELECT 2,460,0,0,0,0,'FT',0, 0,0,0
	UNION ALL SELECT 2,22,1,1,0,0,'FT',3, 0,0,1
	--#93654	
	UNION ALL SELECT 2,465,0,0,0,0,'FT',0, 0,0,0
	UNION ALL SELECT 1,466,0,0,1,0,'1H',0, 0,0,0

	-- Start #115232
	UNION ALL SELECT 2,470,0,0,0,0,'FT',0,0,1,0
	UNION ALL SELECT 1,471,0,0,1,0,'1H',0,0,1,0
	UNION ALL SELECT 2,472,0,0,1,0,'2H',0,0,1,0
	UNION ALL SELECT 2,473,1,0,0,0,'FT',3,0,0,0
	UNION ALL SELECT 1,474,1,0,1,0,'1H',1,0,0,0
	UNION ALL SELECT 2,475,1,0,0,0,'FT',3,0,0,0
	UNION ALL SELECT 1,476,1,0,1,0,'1H',1,0,0,0
	UNION ALL SELECT 2,477,0,0,0,0,'FT',0,0,0,0
	UNION ALL SELECT 1,478,0,0,1,0,'1H',0,0,0,0
	UNION ALL SELECT 8,479,0,0,0,1,'FT',0,0,0,0
	UNION ALL SELECT 8,481,0,0,0,1,'2H',0,0,0,0
	UNION ALL SELECT 2,482,1,0,0,0,'FT',3,0,1,0
	UNION ALL SELECT 2,483,1,0,0,0,'FT',3,0,1,0
	UNION ALL SELECT 1,484,1,0,1,0,'1H',1,0,1,0
	UNION ALL SELECT 1,485,1,0,1,0,'1H',1,0,1,0
	-- resource = 08, using goal record		 
	UNION ALL SELECT 2,486,1,1,0,0,'FT',3,0,0,0
	UNION ALL SELECT 1,487,1,1,1,0,'1H',1,0,0,0
	UNION ALL SELECT 2,488,1,1,0,0,'FT',3,0,0,0
	UNION ALL SELECT 1,489,1,1,1,0,'1H',1,0,0,0
	UNION ALL SELECT 2,490,1,1,1,0,'2H',2,0,0,0
	UNION ALL SELECT 2,491,0,1,0,0,'FT',0,0,0,0
	UNION ALL SELECT 1,492,0,1,1,0,'1H',0,0,0,0
	-- end									 
	UNION ALL SELECT 2,493,1,0,1,0,'FT',3,0,0,0
	UNION ALL SELECT 1,494,1,0,1,0,'1H',1,0,0,0
	UNION ALL SELECT 2,495,1,0,1,0,'2H',2,0,0,0
	UNION ALL SELECT 2,496,1,0,1,0,'FT',2,0,0,0
	UNION ALL SELECT 2,497,1,0,1,0,'FT',2,0,0,0
	-- End									
											
	-- Start - Redmine: #112885 - Incorporate PHAIO 4
	UNION ALL SELECT 2,467,1,0,1,0,'FT',3,0,0,0
	UNION ALL SELECT 2,468,0,0,0,0,'FT',0,0,0,0
	UNION ALL SELECT 2,469,1,0,0,0,'FT',3,0,0,0
											 
	-- Badminton All In One [Redmine #120324]
	UNION ALL SELECT 2,701,0,0,0,0,'FT',0,0,1,0
	UNION ALL SELECT 2,702,0,0,0,0,'FT',0,0,1,0
	UNION ALL SELECT 2,703,0,0,0,0,'FT',0,0,0,0
	UNION ALL SELECT 2,704,0,0,0,0,'FT',0,0,1,0
	UNION ALL SELECT 2,705,0,0,0,0,'FT',0,0,1,0
	UNION ALL SELECT 2,706,0,0,0,0,'FT',0,0,1,0
	UNION ALL SELECT 1,707,0,0,0,0,'Special',0,0,0,0
	UNION ALL SELECT 1,708,0,0,0,0,'Special',0,0,1,0
	UNION ALL SELECT 1,709,0,0,0,0,'Special',0,0,1,0
	UNION ALL SELECT 1,710,0,0,0,0,'Special',0,0,1,0
	UNION ALL SELECT 1,711,0,0,0,0,'Special',0,0,0,0
	UNION ALL SELECT 1,712,0,0,0,1,'Special',0,0,0,0
	UNION ALL SELECT 1,713,0,0,0,1,'Special',0,0,0,0
	UNION ALL SELECT 1,714,0,0,0,0,'Special',0,0,0,0
												  
	-- Start - Redmine: #121681 - Incorporate PHAIO 5
	UNION ALL SELECT 8,395,0,0,0,1,'FT',0,0,0,0	  
	UNION ALL SELECT 8,393,0,0,0,1,'FT',0,0,0,0	  
	UNION ALL SELECT 8,391,0,0,0,1,'FT',0,0,0,0
	UNION ALL SELECT 8,390,0,0,0,1,'FT',0,0,0,0
	UNION ALL SELECT 8,387,0,0,0,1,'FT',0,0,0,0
	UNION ALL SELECT 8,386,0,0,0,1,'FT',0,0,0,0
	UNION ALL SELECT 8,385,0,0,0,1,'Special',0,0,0,0
	UNION ALL SELECT 8,384,0,0,0,1,'Special',0,0,0,0
	UNION ALL SELECT 8,383,0,0,0,1,'Special',0,0,0,0
	UNION ALL SELECT 8,382,0,0,0,1,'Special',0,0,0,0
	UNION ALL SELECT 8,381,0,0,0,1,'Special',0,0,0,0
	UNION ALL SELECT 8,376,0,0,0,1,'Special',0,0,0,0
												  
	UNION ALL SELECT 2,400,0,0,0,0,'FT',0,0,0,0	  
	UNION ALL SELECT 2,399,1,0,0,0,'FT',3,0,0,0	  
	UNION ALL SELECT 2,398,0,0,0,0,'FT',0,0,0,0	  
	UNION ALL SELECT 2,397,1,0,0,0,'FT',3,0,0,0	  
	UNION ALL SELECT 2,396,1,1,0,0,'FT',3,0,0,0	  
	UNION ALL SELECT 2,394,0,0,0,0,'FT',0,0,0,0
	UNION ALL SELECT 2,392,1,0,0,0,'FT',3,0,0,0
	UNION ALL SELECT 2,389,1,0,0,0,'FT',3,0,0,0
	UNION ALL SELECT 2,388,1,0,0,0,'FT',3,0,0,0
											
	-- End									 

	-- Start: Cricket AIO

		--Group 1: Cricket AIO Major round (ResourceID = '00')
	UNION ALL SELECT 2, 9538, 0, 0, 0, 0, 'FT', 0, 0, 0, 0
	UNION ALL SELECT 2, 9539, 0, 0, 0, 0, 'FT', 0, 0, 0, 0
	UNION ALL SELECT 2, 9606, 0, 0, 0, 0, 'FT', 0, 0, 0, 0
	UNION ALL SELECT 2 ,9604, 0, 0, 0, 0, 'FT' ,0 ,0 ,0 ,0 --Phase 1.2
	UNION ALL SELECT 2 ,9605, 0, 0, 0, 0, 'FT' ,0 ,0 ,0 ,0 --Phase 1.2

		--Group 1: Cricket AIO Major round (Innings)
	UNION ALL SELECT 12, 9404, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9405, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9406, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9407, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9408, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9409, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9496, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9497, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9498, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9499, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9500, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9501, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9541, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9542, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9543, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9544, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9545, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9546, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
		--Group 3: Cricket AIO Early bettype
	UNION ALL SELECT 12, 9400, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9401, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9410, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9411, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9412, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9413, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9414, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9415, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9416, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9417, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9418, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9419, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9420, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9421, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9422, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9423, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9428, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9429, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9430, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9431, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9432, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9433, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9434, 0, 0, 0, 0, 'Special', 0, 0, 0, 0 --Phase 1.2
	UNION ALL SELECT 12, 9435, 0, 0, 0, 0, 'Special', 0, 0, 0, 0 --Phase 1.2
	UNION ALL SELECT 12, 9436, 0, 0, 0, 0, 'Special', 0, 0, 0, 0 --Phase 1.2
	UNION ALL SELECT 12, 9437, 0, 0, 0, 0, 'Special', 0, 0, 0, 0 --Phase 1.2
	UNION ALL SELECT 12, 9438, 0, 0, 0, 0, 'Special', 0, 0, 0, 0 --Phase 1.2
	UNION ALL SELECT 12, 9439, 0, 0, 0, 0, 'Special', 0, 0, 0, 0 --Phase 1.2
	UNION ALL SELECT 12, 9446, 0, 0, 0, 0, 'Special', 0, 0, 0, 0 --Phase 1.2
	UNION ALL SELECT 12, 9447, 0, 0, 0, 0, 'Special', 0, 0, 0, 0 --Phase 1.2
	UNION ALL SELECT 12, 9449, 0, 0, 0, 0, 'Special', 0, 0, 0, 0 --Phase 1.2
	UNION ALL SELECT 12, 9450, 0, 0, 0, 0, 'Special', 0, 0, 0, 0 --Phase 1.2
	UNION ALL SELECT 12, 9452, 0, 0, 0, 0, 'Special', 0, 0, 0, 0 --Phase 1.2
	UNION ALL SELECT 12, 9453, 0, 0, 0, 0, 'Special', 0, 0, 0, 0 --Phase 1.2
	UNION ALL SELECT 12, 9454, 0, 0, 0, 0, 'Special', 0, 0, 0, 0 --Phase 1.2
	UNION ALL SELECT 12, 9455, 0, 0, 0, 0, 'Special', 0, 0, 0, 0 --Phase 1.2
	UNION ALL SELECT 12, 9460, 0, 0, 0, 0, 'Special', 0, 0, 0, 0 --Phase 1.2
	UNION ALL SELECT 12, 9461, 0, 0, 0, 0, 'Special', 0, 0, 0, 0 --Phase 1.2
	UNION ALL SELECT 12, 9490, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9491, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9502, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9503, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9504, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9505, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9506, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9507, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9508, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9509, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9510, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9511, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9512, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9513, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9514, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9515, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9516, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9517, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9518, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9519, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9527, 0, 0, 0, 0, 'Special', 0, 0, 0, 0 --Phase 1.2
	UNION ALL SELECT 12, 9528, 0, 0, 0, 0, 'Special', 0, 0, 0, 0 --Phase 1.2
	UNION ALL SELECT 12, 9530, 0, 0, 0, 0, 'Special', 0, 0, 0, 0 --Phase 1.2
	UNION ALL SELECT 12, 9532, 0, 0, 0, 0, 'Special', 0, 0, 0, 0 --Phase 1.2
	UNION ALL SELECT 12, 9533, 0, 0, 0, 0, 'Special', 0, 0, 0, 0 --Phase 1.2
	UNION ALL SELECT 12, 9540, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9547, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9548, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9549, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9550, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9551, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9552, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9553, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9554, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9555, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9556, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9557, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9558, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9559, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9560, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9561, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9562, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9563, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9564, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9566, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9567, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9569, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9570, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9572, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9573, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9574, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9575, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9580, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9581, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	--Cricket AIO Phase 1.2 (31 bettype)
	UNION ALL SELECT 12, 9442, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9443, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9607, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9608, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9609, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9610, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9611, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9612, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9613, 0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9614, 0, 0, 0, 0, 'Special', 0, 0, 0, 0

	--Cricket AIO Phase 2.0 (174 bettype)
	UNION ALL SELECT 12, 9440,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9441,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9448,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9451,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9456,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9457,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9458,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9459,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9462,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9463,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9464,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9465,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9484,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9485,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9486,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9487,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9488,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9489,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9529,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9531,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9534,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9541,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9542,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9543,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9544,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9545,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 2,  9546,  0, 0, 0, 0, 'FT'	 , 0, 0, 0, 0
	UNION ALL SELECT 12, 9547,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9548,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9549,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9550,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9551,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9552,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9559,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9560,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9561,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9562,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9563,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9564,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9566,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9567,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9569,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9570,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9572,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9573,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9574,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9575,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9576,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9577,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9578,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9579,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9580,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9581,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9582,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9583,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9584,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9585,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9606,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9615,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9616,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9617,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9618,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9619,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9620,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9621,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9622,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9623,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9624,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9625,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9626,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9627,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9628,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9629,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9630,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9631,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9632,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9633,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9634,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9635,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9636,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9637,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9638,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9639,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9640,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9641,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9650,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9651,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9652,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9653,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9654,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9655,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9656,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9657,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9658,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9659,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9660,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9661,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9662,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9663,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9664,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9665,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9666,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9667,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9668,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9669,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9670,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9671,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9672,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9673,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9674,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9675,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9676,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9677,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9678,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9679,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9680,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9681,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9682,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9683,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9684,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9685,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9686,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9687,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9688,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9689,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9690,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9691,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9692,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9693,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9694,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9695,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9696,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9697,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9698,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9699,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9535,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9702,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9703,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9704,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9705,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9536,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9537,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9708,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9709,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9710,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9711,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9712,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9713,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9714,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9715,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9716,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9717,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9718,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9719,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9720,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9721,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9722,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9723,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9724,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9725,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9726,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9727,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9728,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9729,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9730,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9731,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9732,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9733,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9734,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9735,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9736,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9737,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9738,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	UNION ALL SELECT 12, 9739,  0, 0, 0, 0, 'Special', 0, 0, 0, 0
	
	-- End: Cricket AIO

	)										 
GO



