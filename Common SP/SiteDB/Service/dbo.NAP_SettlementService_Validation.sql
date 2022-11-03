/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SettlementService_Validation]
	@TransInfo XML = NULL
	,@TransInfoJson	VARCHAR(MAX) = NULL
	,@TableName VARCHAR(128)
	,@IsPassed BIT = 0 OUTPUT
AS
/*
	Created by: 20201123@Kathy
	Task: Settlement  
	
	Revisions:
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
		- 20221025@Louisa: Use JSon log format for soccer [Redmine:#179449]

	Param's Explanation:  
		   
*/
BEGIN	
	SET NOCOUNT ON
	
	DECLARE @cnt_sitedb INT
			,@cnt_central INT
	
	SELECT @cnt_sitedb = 0
			,@cnt_central = 0
			,@IsPassed = 0

	DECLARE @tmpTransId TABLE (TransId BIGINT)

	IF @TransInfo IS NOT NULL
	BEGIN
		INSERT INTO @tmpTransId(TransId)
		SELECT	T.C.value('./@t', 'bigint') AS transid
		FROM	@TransInfo.nodes('/root/r') AS T(C)
		OPTION (OPTIMIZE FOR (@transInfo = NULL ))
	END
	ELSE
	BEGIN
		INSERT INTO @tmpTransId(TransId)
		SELECT t FROM OPENJSON(@TransInfoJson) WITH ( t BIGINT)
	END

	SET @cnt_sitedb = @@ROWCOUNT

	IF @TableName = 'bettrans'
	BEGIN
		SELECT @cnt_central = COUNT(1)
		FROM	@tmpTransId t
		WHERE	EXISTS (SELECT TOP 1 1 
						FROM dbo.bettrans b WITH(NOLOCK) 
						WHERE b.transid = t.TransId
				)
	END
	ELSE IF @TableName = 'bettransm'
	BEGIN
		SELECT @cnt_central = COUNT(1)
		FROM	@tmpTransId t
		WHERE	EXISTS (SELECT TOP 1 1 
						FROM dbo.bettransm b WITH(NOLOCK) 
						WHERE b.transid = t.TransId
				)
	END
	ELSE
	BEGIN
		SET @IsPassed = 1
	END

	IF @cnt_sitedb = @cnt_central
		SET @IsPassed = 1

END