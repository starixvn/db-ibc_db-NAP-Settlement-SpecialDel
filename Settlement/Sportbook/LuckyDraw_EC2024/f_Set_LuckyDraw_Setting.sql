/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="1"></info>*/
CREATE FUNCTION dbo.f_Set_LuckyDraw_Setting()
RETURNS TABLE
WITH SCHEMABINDING
AS
/*	
	Created: 20240327@Louisa
    Task: EC 2024-Correct Score Sharing and Lucky Draw-(Pool prize) [Redmine:#202309]
	DB: DBCTG bodb02

	Revision: 20240327@Louisa initial [Redmine:#202309]
*/
RETURN
	(
	SELECT l.LeagueID, l.IsTest
	FROM ( 
			VALUES( 114866)
					,( 99008 )
					,(3)
					,(165)
			)T(LeagueId)
		INNER JOIN dbo.League l WITH(NOLOCK)
			ON t.LeagueId = l.leagueid
	)
GO