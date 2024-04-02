/*<info serverAlias="DBCTG-bodb02,DBSIG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Settlement_LuckyDrawMember_Select]
	  @MatchID		INT
	 ,@MinBet		INT
AS
/*
	Created by: 20240401@Aries
	Task: Settlement  
	DB: DBCTG-bodb02
	
	Revisions:
		- 20240401@Aries: EC 2024-Correct Score Sharing and Lucky Draw-(Pool prize) [Redmine:#202309]

	Param's Explanation:  	   
*/
BEGIN	
	SET NOCOUNT ON
	
	SELECT	 transId
			,custId
	FROM bettrans WITH(NOLOCK)
	WHERE matchid = @MatchID
		AND bettype = 413
		AND stake*actualrate >= @Minbet
		AND status = 'WON'
END