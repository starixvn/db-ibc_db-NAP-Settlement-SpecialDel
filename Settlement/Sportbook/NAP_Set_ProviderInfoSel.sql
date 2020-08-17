/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet " viewers="" isFunction="0"></info>*/
ALTER PROC [dbo].[NAP_Set_ProviderInfoSel]
(
	 @SourceName VARCHAR(MAX) = ''
	,@GameTypes  VARCHAR(MAX) =  ''
	,@SourceStatus	 SMALLINT = 1
	,@SourceType SMALLINT
)
AS
/*
    Created by: 20200805@Louisa
    Task: get provider info [Redmine:#138656]
    DB: DBPRO/BODB02 
    
    Revisions:            
		- 20200805@Louisa: get provider and OutsideSource info [Redmine:#138656]

	Param's Explanation:
		@GameTypes		: '1,2,3,4'
		@SourceStatus	: Status of provider ( 0: Inactive		1: Active	99: Get all )
		@SourceType		: 0: Provider Source  1: Outsite source
		If get Provider : input  @GameTypes , @SourceType
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpSource TABLE (SourceId SMALLINT )
	DECLARE @tmpGameType TABLE (GameType TINYINT)
	
	IF( @SourceType = 0 ) 
	BEGIN
		SELECT @SourceName  =''
	END

	IF ISNULL(@SourceName,'') <>''
	BEGIN
		INSERT INTO @tmpSource (SourceId)
		SELECT  pi.SourceId 
		FROM	ProviderInfo pi WITH(NOLOCK) 
		WHERE	pi.SourceName LIKE '%'+ @Sourcename + '%' OR pi.Remark LIKE '%'+ @Sourcename + '%' 
		AND @SourceType  = 1 
		AND pi.SourceId > 1001
	END

	ELSE 
	BEGIN
		IF ISNULL(@GameTypes, '') <> ''	
			INSERT INTO @tmpSource (SourceId)
			SELECT  DISTINCT pgm.SourceId 
			FROM	ProviderGameTypeMapping pgm WITH(NOLOCK)
				INNER JOIN  dbo.f_SplitString(@GameTypes, ',') fs
					ON pgm.GameType = fs.Val
			WHERE pgm.isActive = 1
	END
 
	SELECT 	 pi.SourceId
			,pi.SourceName
			,pi.Remark
			,pi.isActive	AS SourceStatus
			,pgm.GameType
			,pgm.OrderNo
			,pgm.isActive
	FROM  ProviderInfo pi WITH(NOLOCK)
		INNER JOIN ProviderGameTypeMapping pgm WITH(NOLOCK)
			ON pi.SourceId = pgm.SourceId
	WHERE  ( pi.Isactive =  @SourceStatus OR @SourceStatus  = 99)
		AND (
				(
					(pi.SourceId IN (SELECT SourceId FROM @tmpSource ) OR @GameTypes ='')
					AND @SourceType  = 1 
					AND pi.SourceId > 1001
				)
				OR 
				(@SourceType = 0 
					AND pi.SourceId < 1001 
					AND pi.SourceId <> 100 
					AND  pgm.GameType IN (SELECT fs.Val FROM dbo.f_SplitString(@GameTypes, ',') fs) 
					AND pgm.isActive = 1
				)
			)
	ORDER BY CASE @SourceType
				WHEN 1 THEN  pi.SourceId
				WHEN 0 THEN CASE OrderNo WHEN 0 THEN 9999 ELSE OrderNo END
			END, SourceName
END
GO