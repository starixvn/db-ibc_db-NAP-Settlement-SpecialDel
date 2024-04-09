/*<info serverAlias="DBSIG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Settlement_LuckyDrawMember_Select]
	  @MatchID		INT
	 ,@MinBet		INT
	 ,@IsTest		BIT
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
	
	IF @Istest IS NULL
	SET @IsTest = 0

	SELECT	 b.transId
			,b.custId
			,b.statusID
	FROM bettrans b WITH(NOLOCK)
	WHERE matchid = @MatchID
		AND bettype = 413
		AND stake * (CASE WHEN @IsTest = 1 AND b.currency = 20 THEN 1 ELSE actualrate END) >= @Minbet
		AND status = 'WON'
		AND 1 = CASE WHEN @IsTest = 1 THEN 1
					 WHEN @IsTest = 0 AND b.currency NOT IN (20,27,28,72,213) THEN 1
					 ELSE 0
					 END
END