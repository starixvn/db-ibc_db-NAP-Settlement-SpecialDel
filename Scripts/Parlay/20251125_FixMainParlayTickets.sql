/*<info serverAlias="DBCTG-bodb02,DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[ExecRep_NAP_Admin_06]
/*	
	Creator: Helen
	Date: 20251125
	DB: DBTXN/bodb02

	Revisions:
		- 20251125@Helen: running ticket for parlay, sub already move to 14  [Redmine:#0000]

*/	
AS
BEGIN
	SET NOCOUNT ON

	IF OBJECT_ID (N'BetParlayResult', N'U') IS NULL 
		RETURN
	
	IF @@SERVERNAME NOT LIKE 'DB04%'
		AND @@SERVERNAME NOT IN ('DB054', 'DB054C2\DB054', 'DB055', 'SITDB055')
		AND @@SERVERNAME NOT LIKE 'SITDB04%'
	BEGIN 
		-- Update BetparlayResult
		UPDATE r	
			SET statusid = 113, awinlost = 9.2000, odds = 8.0280, winlostdate = '2025-11-24'
		FROM BetparlayResult r WITH (ROWLOCK,UPDLOCK)
		WHERE refno= 28585526890070019 AND r.serial = 4030001
	    
	END
END