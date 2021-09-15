/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_ChildMatchSel]
(
	 @MatchId INT
)
AS
/* 
	Created by: 20210906@Louisa
    Task: 20210906@Louisa: Settle by profile for Volleyball, Squash, Sepak Takraw [Redmine:#160478]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20210906@Louisa: Get child match for Volleyball [Redmine:#160478]
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @tmpChildmatchInfo TABLE
	(
	  matchid			INT
	 ,matchcode			NVARCHAR(100)
	 ,sporttype			SMALLINT
	 ,leagueid			INT
	 ,eventstatus		NVARCHAR(100)
	 ,SettlementStatus	TINYINT
	 ,ChildMatchType	TINYINT
	 ,ConfirmFT			BIT
	 ,betstatus			NVARCHAR(100)
	 ,ResourceID		VARCHAR(20)
	 ,HomeValue			VARCHAR(50)
	 ,AwayValue			VARCHAR(50)
	 ,FinalHomeScore	INT
	 ,FinalAwayScore	INT
	 ,SettlementStatusID	TINYINT
	 ,ResultStatusID	TINYINT
	 ,ResultSetting		TINYINT
	)

	INSERT INTO @tmpChildmatchInfo
	(
		  matchid			
		 ,matchcode
		 ,sporttype			
		 ,leagueid			
		 ,eventstatus		
		 ,SettlementStatus	
		 ,ChildMatchType	
		 ,ConfirmFT			
		 ,betstatus			
		 ,ResourceID		
		 ,HomeValue			
		 ,AwayValue
		 ,FinalHomeScore
		 ,FinalAwayScore		
		 ,SettlementStatusID
		 ,ResultStatusID	
		 ,ResultSetting		
	)
	SELECT   m.matchid
			,m.matchcode
			,m.sporttype
			,m.leagueid
			,m.eventstatus
			,m.SettlementStatus
			,m.ChildMatchType
			,CASE mr.ConfirmFT WHEN 0 THEN 0 ELSE 1 END AS ConfirmFT
			,m.betstatus
			,r.ResourceID
			,r.HomeValue
			,r.AwayValue
			,m.finalhomescore
			,m.finalawayscore
			,r.SettlementStatusID
			,r.ResultStatusID
			,r.ResultSetting
	FROM dbo.match m WITH(NOLOCK)
		INNER JOIN dbo.match_remark mr WITH(NOLOCK) 
			ON m.matchid = mr.matchid
		LEFT JOIN dbo.ResultDetailOS r WITH(NOLOCK)
			ON m.matchid = r.MatchID
	WHERE ISNULL(m.ParentID,0) = @MatchId

	IF EXISTS 
	(
		SELECT TOP 1 1 FROM @tmpChildmatchInfo m 
		WHERE m.HomeValue IS NULL				--- not exists data in resultDetail	 
		AND m.ResultSetting IS NULL	
		AND ISNULL(m.finalhomescore,'') <> ''	--- exist confirmed score or settled score
		AND m.betstatus NOT LIKE '%Refund%'			
	)
	BEGIN

		SELECT DISTINCT m.matchid			
			 ,m.matchcode		
			 ,m.leagueid			
			 ,m.eventstatus		
			 ,m.SettlementStatus	
			 ,m.ChildMatchType		
			 ,m.betstatus
			 ,m.ConfirmFT			
			 ,'00'		
			 ,CAST( FinalHomeScore AS VARCHAR(5) )
			 ,CAST( FinalAwayScore	AS VARCHAR(5) )		
			 ,m.SettlementStatusID
			 ,m.ResultStatusID	
			 ,m.ResultSetting
		FROM @tmpChildmatchInfo m
		WHERE m.FinalHomeScore IS NOT NULL

	END
	
	ELSE
	SELECT m. matchid			
			,m.matchcode		
			,m.leagueid			
			,m.eventstatus		
			,m.SettlementStatus	
			,m.ChildMatchType		
			,m.betstatus
			,m.ConfirmFT			
			,m.ResourceID		
			,m.HomeValue			
			,m.AwayValue			
			,m.SettlementStatusID
			,m.ResultStatusID	
			,m.ResultSetting
	FROM @tmpChildmatchInfo m
	ORDER BY m.Matchid, m.ResourceID

END
GO
