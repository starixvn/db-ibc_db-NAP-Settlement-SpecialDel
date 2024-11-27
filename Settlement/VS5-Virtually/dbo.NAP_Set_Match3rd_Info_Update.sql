/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_Match3rd_Info_Update]
(
     @MatchId						INT
	,@EventStatus					VARCHAR(50)		   = NULL	 
	,@BetStatus						VARCHAR(50)		   = NULL
	,@SelectedResources			    VARCHAR(MAX)       = NULL
	
)
AS
/*
    Creator: 20240704@Aries 
	Task: VS5 - Virtually Sports
	DB: DBPRO-bodb02
	
	Revision:
		- 20240704@Aries: Initial [Redmine:#207309]
		- 20241023@Louisa: Virtual Basketball [Redmine:#210733]

    Parameters Explanation:
		 @SelectedResources = <Resources>
                                    <Resource Id="00" Home="1" Away="3" /> 
                                    <Resource Id="01" Home="1" Away="2" />
                              </Resources> 

*/
BEGIN
    SET NOCOUNT ON

    DECLARE  @FTHome		INT
			,@FTAway	    INT
			,@HTHome	    INT
			,@HTAway	    INT
			,@handle		INT
			,@HasHTScore	BIT = 0
			,@HasFTScore	BIT = 0

	DECLARE @tmpSelectedRID TABLE(ResourceID VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50))

	EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedResources
	INSERT INTO @tmpSelectedRID(ResourceID, HomeValue, AwayValue)
	SELECT Id, Home, Away
	FROM OPENXML(@handle,'Resources/Resource',1) WITH( Id	VARCHAR(20)
														,Home VARCHAR(50)
														,Away VARCHAR(50)
										) AS tbl
	EXEC sp_xml_removedocument @handle

	SELECT TOP(1)	
		 @HTHome = IIF(ISNULL(HomeValue,'') = '',NULL,HomeValue)
		,@HTAway = IIF(ISNULL(AwayValue,'') = '',NULL,AwayValue) 
		,@HasHTScore = 1
  	FROM @tmpSelectedRID sr
  	WHERE sr.ResourceID = '01'

	SELECT TOP(1) 
		 @FTHome = IIF(ISNULL(HomeValue,'') = '',NULL,HomeValue)
		,@FTAway = IIF(ISNULL(AwayValue,'') = '',NULL,AwayValue) 
		,@HasFTScore = 1
  	FROM @tmpSelectedRID sr
  	WHERE sr.ResourceID = '00'

    UPDATE  dbo.Match3rd WITH(ROWLOCK, UPDLOCK)
    SET   eventstatus		= ISNULL(@EventStatus, eventstatus)
	     ,BetStatus			= @BetStatus
		 ,hthomescore		= IIF(@HasHTScore = 1, @HTHome, hthomescore)
		 ,htawayscore		= IIF(@HasHTScore = 1, @HTAway, htawayscore)
		 ,finalhomescore	= IIF(@HasFTScore = 1, @FTHome, finalhomescore)
		 ,finalawayscore	= IIF(@HasFTScore = 1, @FTAway, finalawayscore)
         ,UpdateTime		= GETDATE()
    WHERE   Match3rdId = @MatchId
 

	
END
GO

