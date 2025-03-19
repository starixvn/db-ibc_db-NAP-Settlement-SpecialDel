/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb0" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_PoolHouseTicket_Select]
(	
	@MatchId              INT = 0
	,@RequestId			  INT = 0
	,@IssueTypeId		  INT = 0
	,@ActionId			  INT = 5
	,@SubIssueTypeId	  INT = NULL
	,@FilterFromTransTime DATETIME = NULL
	,@FilterToTransTime	  DATETIME = NULL
	,@IsLinkGroup1X2	  BIT = 0
	,@IsLinkGroupAIO	  BIT = 0
	,@LiveIndicator		  BIT = 0
	,@HomeFavorite		  VARCHAR(50) = NULL
	,@AwayFavorite		  VARCHAR(50) = NULL
	,@HdpValue			  VARCHAR(50) = NULL
	,@WrongMarket         VARCHAR(50) = NULL
	,@WrongOddsInfo		  VARCHAR(MAX) = NULL
)
AS
/*	
	Created by: 20220523@July
	Task: Affected Pool House Ticket popup  [Redmine: #172486]
	DB: DBCTG/bodb02,DBSIC-bodb02,DBSID-bodb0
	
	Revisions: 
		- 20220523@July: TVS - Wrong HDP affects to PH bet types [Redmine: #172486]
		- 20230103@Max: Change JSON input [Redmine: #180625]
		- 20230403@July: TVS - Wrong OU affects to PH bet types [Redmine: #172975]
		- 20230419@Max: [TVS] New issue type Wrong Odds [Redmine: #179934]
		- 20250319@Lani: [TVS] Enhance out of memory issue - remove TransInfoJson [Redmine: #217771]

	Param's explanation:


*/
BEGIN
	SET NOCOUNT ON

	IF @IssueTypeId IN (4,5) 
	BEGIN
		EXEC TicketVoiding_PoolHouseTicket_HDP_Select
			 @MatchId              = @MatchId
			,@RequestId			   = @RequestId
			,@IssueTypeId		   = @IssueTypeId
			,@ActionId			   = @ActionId
			,@SubIssueTypeId	   = @SubIssueTypeId
			,@FilterFromTransTime  = @FilterFromTransTime
			,@FilterToTransTime	   = @FilterToTransTime
			,@IsLinkGroup1X2	   = @IsLinkGroup1X2
			,@IsLinkGroupAIO	   = @IsLinkGroupAIO
			,@LiveIndicator		   = @LiveIndicator
			,@HomeFavorite		   = @HomeFavorite
			,@AwayFavorite		   = @AwayFavorite
			,@HdpValue			   = @HdpValue
	END
	IF @IssueTypeId IN (6,7) 
	BEGIN
		EXEC TicketVoiding_PoolHouseTicket_OU_Select
			 @MatchId              = @MatchId
			,@RequestId			   = @RequestId
			,@IssueTypeId		   = @IssueTypeId
			,@ActionId			   = @ActionId
			,@SubIssueTypeId	   = @SubIssueTypeId
			,@FilterFromTransTime  = @FilterFromTransTime
			,@FilterToTransTime	   = @FilterToTransTime
			,@IsLinkGroup1X2	   = @IsLinkGroup1X2
			,@IsLinkGroupAIO	   = @IsLinkGroupAIO
			,@LiveIndicator		   = @LiveIndicator
			,@WrongMarket		   = @WrongMarket
	END
	IF @IssueTypeId = 2
	BEGIN
		EXEC dbo.TicketVoiding_PoolHouseTicket_WO_Select
			@RequestId			   = @RequestId
			,@IssueTypeId		   = @IssueTypeId
			,@ActionId			   = @ActionId
			,@WrongOddsInfo		   = @WrongOddsInfo
	END
	SET NOCOUNT OFF
END