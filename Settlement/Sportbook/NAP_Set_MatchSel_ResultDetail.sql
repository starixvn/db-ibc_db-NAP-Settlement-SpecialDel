/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSel_ResultDetail]
	@matchidList 		   VARCHAR(MAX)
	,@SportType            INT
	

AS
/*
    Created by: 20180802@Vicky
    Task: get ResultDetail
    DB: DBPRO/BODB02 
    
    Revisions:            
		- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		
*/
BEGIN
	SET NOCOUNT ON
    
	DECLARE @tblResource TABLE(ResourceID VARCHAR(20))
	DECLARE @tblMatchID TABLE(matchid VARCHAR(20))
	DECLARE @ResourceList VARCHAR(MAX) = ''
    ---------------------------------------------------------------------------------------------
    
	INSERT INTO @tblMatchID(matchid)
	SELECT Val 
	FROM dbo.f_SplitString(@matchidList, ',')
	OPTION (maxrecursion 0)
	
	/*SELECT @ResourceList = @ResourceList + ',' + ResourceID
	FROM dbo.f_Set_MajorRound(@Sporttype)
	SET @ResourceList = @ResourceList + ','*/
	
    IF @Sporttype = 43
    BEGIN
        SELECT    rs.MatchId
                , rs.ResourceId
                , rs.HomeValue
                , rs.AwayValue
                , rs.ResultStatusID
                , rs.SettlementStatusID
        FROM    dbo.[ResultDetailES] rs WITH (NOLOCK) 
    	WHERE MatchID IN (SELECT matchid FROM @tblMatchID)
    		AND EXISTS (SELECT 1 
    					FROM dbo.f_Set_MajorRound(@Sporttype) f 
    					WHERE rs.ResourceID = f.ResourceID)
	END
	ELSE
	BEGIN
    	SELECT    rs.MatchId
                , rs.ResourceId
                , rs.HomeValue
                , rs.AwayValue
                , rs.ResultStatusID
                , rs.SettlementStatusID
        FROM    dbo.[ResultDetail] rs WITH (NOLOCK) 
    	WHERE MatchID IN (SELECT matchid FROM @tblMatchID)
    		AND EXISTS (SELECT 1 
    					FROM dbo.f_Set_MajorRound(@Sporttype) f 
    					WHERE rs.ResourceID = f.ResourceID)
	END
END
GO
