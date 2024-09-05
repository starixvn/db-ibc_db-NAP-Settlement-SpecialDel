/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_Settlement_Betbuilder_Validation_Event
(
	 @matchid			INT				= 0
	,@IsAuto			BIT				= 0
	,@SelectedSelection	VARCHAR(MAX)
)
AS
/*
	Created: 20220719@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20220719@Louisa: Validation event before settle 3rd [Redmine:#175251]
		- 20240625@Aries: Enhance the error message when settle with the NULL result for Bebuilder [Redmine:#206992]
		- 20240905@Aries: Enhance the settlement by Selection for Betbuilder  [Redmine:#208782]

	Param's Explanation:
		- @SelectedSelection:	<Resources>
									<Resource Id="200" Result="WON"/>
									<Resource Id="201" Result="WON"/>
									<Resource Id="202" Result="WON"/>
									<Resource Id="203" Result="REFUND"/>
									<Resource Id="204" Result="LOSE"/>
								</Resources>
					
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE  @sportType			INT
			,@AutoSetting		TINYINT
			,@xmlData			XML
	
	DECLARE @tblSelectionType		TABLE(SelectionType INT, Result VARCHAR(20))
	DECLARE @tblMess				TABLE(ErrorCode INT, ErrorMessage VARCHAR(300))
	DECLARE @tblReason				TABLE(SelectionType INT, Reason VARCHAR(20))

	SET @xmlData = CAST(@SelectedSelection AS XML)
	
	SELECT   @sportType 		= m.sportType
			,@AutoSetting		= ISNULL(m.AutoSetting, l.AutoSetting)
	FROM	dbo.match m WITH(NOLOCK) 
		INNER JOIN dbo.league l WITH(NOLOCK)
			ON m.leagueid = l.leagueid
	WHERE	m.matchid = @MatchId

	IF ISNULL(@sportType,0) = 0
	BEGIN
		INSERT INTO @tblMess(ErrorCode,ErrorMessage)
		SELECT	 1000001 AS ErrorCode, 'Match does not exist!' AS ErrorMessage	
	END 

	IF @IsAuto = 1 AND NOT EXISTS (SELECT TOP 1  1 FROM @tblMess)
	BEGIN
		IF @AutoSetting & 8 = 0  -- 100 is setting of BetBuilder
		BEGIN
			INSERT INTO @tblMess(ErrorCode,ErrorMessage)
			SELECT	 1001017 AS ErrorCode, 'The auto-settlement failed due to OFF setting.' AS ErrorMessage	
		END
		
		;WITH CTE AS (
			SELECT   T.C.value('@Id', 'INT') AS SelectionType
					,T.C.value('@Result', 'VARCHAR(20)') AS Result
			FROM @xmlData.nodes('/Resources/Resource') AS T(C)
		)
		INSERT INTO @tblSelectionType(SelectionType, Result)
		SELECT	SelectionType, Result
		FROM CTE

		INSERT INTO @tblReason(SelectionType,Reason)
		SELECT  SelectionType
			   ,CASE WHEN st.Result NOT IN  ('WON', 'LOSE', 'REFUND') THEN 'Invalid' 
					 WHEN m.MarketId IS NULL THEN 'NotFound'
					 WHEN m.ResultStatusId IN (2,5) THEN 'Settled'
				END AS Reason
		FROM @tblSelectionType AS st
			OUTER APPLY (
				SELECT TOP 1 ms.MarketId,ms.ResultStatusId 
				FROM  SMP_MarketSelection AS ms WITH(NOLOCK) 
				WHERE ms.matchid = @matchid
					AND ms.SelectionType =  st.SelectionType
			) AS m
		WHERE  1 = CASE WHEN st.Result NOT IN  ('WON', 'LOSE', 'REFUND') THEN 1
						WHEN m.MarketId IS NULL THEN 1
						WHEN m.ResultStatusId IN (2,5) THEN 1
						ELSE 0
				   END
	END
	SELECT ErrorCode,ErrorMessage FROM @tblMess;
	SELECT SelectionType,Reason FROM @tblReason;
END
GO