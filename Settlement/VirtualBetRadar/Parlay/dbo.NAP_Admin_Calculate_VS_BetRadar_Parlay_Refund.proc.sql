/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Admin_Calculate_VS_BetRadar_Parlay_Refund] 
	@MatchId			INT
	,@strRefnos			VARCHAR(MAX)
	,@matchdate			SMALLDATETIME
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			NVARCHAR(200)	= ''	OUTPUT
AS
/*	Creator: 20170106@Bobby
	Task: 77720 - Implement BetRadar VS League & Nation for Parlay Refund
	DB: DBTXN/BODB02
	
	Revisions:
		- 20160606@Bobby: Initialize
		- 20170829@Kathy: 	Change datatype of bettransm.TransId [Redmine:#73545]
		- 20220711@Kathy: Do not use SELECT INTO [Redmine:#175276]
		
	Param's Explanation:
 
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @xmlRefno	 	XML
	DECLARE @IgnoreList 	VARCHAR(200)
	DECLARE @tempRefno 		TABLE (refno BIGINT)

	CREATE TABLE #TempData (TransId BIGINT)
	
	--CONVERT refno
	SET @xmlRefno = CONVERT(XML, @strRefnos)
	
	INSERT INTO @tempRefno (refno)
	SELECT T.C.value('./@rn', 'BIGINT') AS refno
	FROM @xmlRefno.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@xmlRefno = NULL ))
	
	IF (@@ROWCOUNT = 0) RETURN
	
	SELECT @ErrCode				= 0
		, @ErrMsg				= ''
		, @IgnoreList 			= 'DB04,DB042,DB043,DB044'
	
	--SELECT parlay tickets
	INSERT INTO #TempData(TransId)
	SELECT transid		
	FROM dbo.bettransm bm WITH(ROWLOCK)
		INNER JOIN @tempRefno temp 
			ON bm.refno = temp.refno
	WHERE bm.matchid 	= @matchid 
		AND bm.statusID NOT IN (101,102) --void/reject

	IF @@ROWCOUNT = 0 RETURN	
		
	DECLARE @_xml XML, @_sXML varchar(MAX)
	DECLARE @subtable TABLE(transid BIGINT)
	
	BEGIN TRY
		WHILE (1 = 1)
		BEGIN
			DELETE @subtable
			
			DELETE TOP (1000) #TempData
			OUTPUT deleted.transid
			INTO @subtable(transid)	
			
			IF @@ROWCOUNT = 0 BREAK
			
			SET @_xml = (
				SELECT 
					transid '@t'
					,@matchdate '@d'
					,0 '@w'
					,103 '@s'				
				FROM @subtable
				FOR XML PATH('r'), ROOT('root'), TYPE
			) 
			SELECT @_sXML = CONVERT(varchar(max), @_xml)
			
			EXEC dbo.Bet_ExecRep_05 
				@IgnoreList 	= @IgnoreList
				, @updatetype 	= 5
				, @_sXML 		= @_sXML
				, @Action		= 'REFUND'
				, @MatchId		= @MatchId
									
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER()
			, @ErrMsg 	= ERROR_MESSAGE()
	END CATCH
	
END
GO