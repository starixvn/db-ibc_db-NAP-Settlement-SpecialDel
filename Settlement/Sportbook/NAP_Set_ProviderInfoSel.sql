/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet " viewers="" isFunction="0"></info>*/
ALTER PROC [dbo].[NAP_Set_ProviderInfoSel]
(
	 @SourceName	VARCHAR(MAX) = ''
	,@GameTypes		VARCHAR(MAX) =  ''
	,@SourceStatus	SMALLINT = 1
	,@SourceType	SMALLINT
	,@Sporttype		SMALLINT = 43
)
AS
/*
    Created by: 20200805@Louisa
    Task: get provider info [Redmine:#138656]
    DB: DBPRO/BODB02 
    
    Revisions:            
		- 20200805@Louisa: get provider and OutsideSource info [Redmine:#138656]
		- 20210305@Louisa: SOP for Tennis [Readmine:#150425]
		- 20220509@Kathy: Change to use STRING_SPLIT [Redmine:#172461]

	Param's Explanation:
		@GameTypes		: '1,2,3,4' (Esports)
						
		@SourceStatus	: Status of provider ( 0: Inactive		1: Active	99: Get all )
		@SourceType		: 0: Provider Source  
						  1: Outsite source
		If get Provider : input  @GameTypes , @SourceType
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpSource TABLE (SourceId SMALLINT )
	DECLARE @tmpGameType TABLE (GameType TINYINT)
	
	IF ( @SourceType = 0 ) 
		SELECT @SourceName  = ''
	
	IF ( ISNULL(@SourceName,'') <> '' )
		SELECT @SourceStatus = 99

	SELECT  p.SourceId
		   ,p.SourceName
		   ,p.Remark
		   ,p.isActive	AS SourceStatus
		   ,pgm.GameType
		   ,pgm.OrderNo
		   ,pgm.isActive
	FROM ProviderInfo p WITH(NOLOCK)
		INNER JOIN dbo.ProviderGameTypeMapping pgm WITH(NOLOCK)
			ON p.SourceId = pgm.SourceId
	WHERE pgm.Sporttype = @Sporttype
		AND (p.isActive = @SourceStatus OR @SourceStatus = 99)
		AND ( @GameTypes = '' OR ( pgm.GameType IN ( SELECT fs.value FROM STRING_SPLIT(@GameTypes, ',') fs) AND pgm.isActive =1)	)
		AND ( p.SourceName LIKE '%'+ @Sourcename + '%' OR ISNULL(p.Remark,'') LIKE '%'+ @Sourcename + '%')
		AND 1 =  CASE WHEN @SourceType = 0 AND p.SourceId < 1001 AND p.SourceId <> 100 AND pgm.isActive = 1 THEN 1
					  WHEN @SourceType = 1 AND p.SourceId > 1001 THEN 1
					  ELSE 0
				 END
	ORDER BY CASE @SourceType WHEN 1 THEN  p.SourceId
							  WHEN 0 THEN CASE OrderNo WHEN 0 THEN 9999 ELSE OrderNo END
			END, SourceName
END
GO