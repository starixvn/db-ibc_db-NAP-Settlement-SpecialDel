/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SideDB_Service_Validation]
	@TransInfo XML
	,@IsPassed BIT = 0 OUTPUT
AS
/*
	Created by: 20201123@Kathy
	Task: Settlement  
	
	Revisions:
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

	Param's Explanation:  
		   
*/
BEGIN	
	SET NOCOUNT ON
	
	DECLARE @cnt_sitedb INT
			,@cnt_central INT
	
	SELECT @cnt_sitedb = 0
			,@cnt_central = 0
	DECLARE @tmpTransId TABLE (TransId BIGINT)

	INSERT INTO @tmpTransId(TransId)
	SELECT	T.C.value('./@t', 'bigint') AS transid
	FROM	@TransInfo.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@transInfo = NULL ))
	
	SET @cnt_sitedb = @@ROWCOUNT

	SELECT @cnt_central = COUNT(1)
	FROM	@tmpTransId t
	WHERE	EXISTS (SELECT TOP 1 1 
					FROM dbo.bettrans b WITH(NOLOCK) 
					WHERE b.transid = t.TransId
			)

	IF @cnt_sitedb = @cnt_central
		SET @IsPassed = 1

END