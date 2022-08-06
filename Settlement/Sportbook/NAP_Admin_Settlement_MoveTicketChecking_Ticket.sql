/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_MoveTicketChecking_Ticket] 
	@MatchId 				INT 
	,@DestinationMatchId	INT
	,@ErrCode 				INT = 0 OUTPUT
	,@ErrMsg 				NVARCHAR(200)	= '' OUTPUT
AS
/*
	Creator: Louisa
	Date: 20210930
	Task: Move ticket
	DB: DBTXN/bodb02

	Revisions:
		Old SP is NAP_Admin_Settlement_MoveTicketChecking
		- 20220719@Louisa: Scale out DBTRANS [Redmine:#175251]

*/

BEGIN

SET NOCOUNT ON
	
	DECLARE @remoteQuery	NVARCHAR(MAX)
			,@IsCentral		BIT = 0
	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	IF OBJECT_ID('tempdb..#tmpTransIds') IS NULL
	CREATE TABLE #tmpTransIds	( RowId INT IDENTITY(1,1) PRIMARY KEY, custid INT, transid BIGINT, oddsid INT,  bettype SMALLINT, BetId INT, liveindicator BIT, StatusId TINYINT, srecommend INT)
	
	IF OBJECT_ID('tempdb..#tmpNewOdds') IS NULL
	CREATE TABLE #tmpNewOdds	( oddsid INT, bettype SMALLINT, liveindicator BIT, ResourceId VARCHAR(20) )

	IF EXISTS (	SELECT TOP 1 1 FROM dbo.bettrans b WITH(NOLOCK) 
				WHERE b.matchid =  @DestinationMatchid 
					AND b.statusID NOT IN ( 101, 102)
					AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
				)
	BEGIN
		SELECT @ErrCode = 1001063
				,@ErrMsg = 'WARNING! Cannot continue due to: Target Match is having running or settled tickets'
		RETURN
	END

	IF EXISTS ( SELECT TOP 1 1 FROM dbo.bettrans b WITH(NOLOCK) 
				WHERE b.matchid = @MatchId
					AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
					AND 1 =  CASE WHEN b.statusID = 1 THEN 1
								  WHEN b.statusID = 0 AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 1
							ELSE 0
							END				
				)
	BEGIN
		SELECT @ErrCode = 1001067
				,@ErrMsg = 'WARNING! Cannot continue due to Source Match is having waiting tickets'
		RETURN
	END

	INSERT INTO #tmpTransIds ( custid, transid, oddsid,  bettype, BetId, liveindicator, StatusId, srecommend )
	SELECT b.custid, b.transid, b.oddsid,  b.bettype, b.BetId, b.liveindicator, b.statusID, b.srecommend
	FROM dbo.bettrans b WITH(NOLOCK)
		LEFT JOIN dbo.MarkedTransaction mk WITH(NOLOCK)
			ON b.transid = mk.TransId
	WHERE b.matchid = @MatchId
		AND b.statusID = 0
		AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		AND mk.TransId IS NULL

	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @ErrCode = 1001063
				,@ErrMsg = 'WARNING! Cannot continue due to: Current has no valid ticket to move'
		RETURN
	END

	SET @remoteQuery = 'SELECT oddsid, bettype, liveindicator, ResourceId 
						FROM DBPRO.bodb02.dbo.OddsES o WITH(NOLOCK)
						WHERE o.matchid = ' + CAST (@DestinationMatchId AS NVARCHAR(20) )
						+' AND ISNULL(o.IsDeleted,0) = 0 '
		
	INSERT INTO #tmpNewOdds ( oddsid, bettype, liveindicator, ResourceId )
	EXEC sys.sp_executesql @remoteQuery
	
	IF EXISTS (
				SELECT TOP 1 1
				FROM #tmpTransIds tr
					LEFT JOIN #tmpNewOdds o 
						ON tr.bettype = o.bettype
						AND tr.liveindicator = o.liveindicator
						AND ( tr.BetId = 0 OR CHARINDEX(o.ResourceId, CAST(tr.betid AS VARCHAR)) > 0 )
				WHERE o.oddsid IS NULL
			)
	BEGIN
		SELECT @ErrCode = 1001065
				, @ErrMsg = 'WARNING! Cannot continue due to: No having Corresponding Oddsid'
		RETURN
	END

END
GO