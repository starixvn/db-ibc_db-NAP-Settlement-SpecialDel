/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Nap_SpecialDelete_MarkTickets_Select] 
	@Status          SMALLINT     = 0,
    @SearchBy        SMALLINT     = 0,
    @MatchId         INT          = 0,
    @Duration        XML          = NULL,
    @LiveIndicator   INT          = 0,
    @LiveHomeScore   SMALLINT     = NULL,
    @LiveAwayScore   SMALLINT     = NULL,
    @CurrencyIDs     VARCHAR(MAX) = NULL,
    @LicenseeNames   VARCHAR(MAX) = NULL,
    @BetTypes        XML          = NULL,
    @TransIds        VARCHAR(MAX) = NULL,
    @Bet             VARCHAR(10)  = 'All'
AS

/*
    Created by: Alan
	Date: 20190325
	Task: Mark Ticket for Settlement Exclusion
	DB: DBTXN/BODB02

	Explanation's Param:
		- @Status: 
			+ 0: Not Marked
			+ 1: Marked
		- @SearchBy:
			+ 0: MatchId
			+ 1: BetIds

	Revisions:
		- 20190325@Alan: - Mark Ticket for Settlement Exclusion [108826]
        - 20200415@Raymond: Mark/Unmark Parlay Tickets and remaing sports [131670]
		- 20220829@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
*/

         BEGIN
             SET NOCOUNT ON;
             IF @Status = 0
                 BEGIN -- Not Marked
                     IF @SearchBy = 0
                         BEGIN -- Select UnMarked Tickets By MatchId
                             EXEC [dbo].[Nap_SpecialDelete_UnMarkedTickets_MatchId_Select]
                                  @MatchId = @MatchId,
                                  @Duration = @Duration,
                                  @LiveIndicator = @LiveIndicator,
                                  @LiveHomeScore = @LiveHomeScore,
                                  @LiveAwayScore = @LiveAwayScore,
                                  @CurrencyIDs = @CurrencyIDs,
                                  @LicenseeNames = @LicenseeNames,
                                  @BetTypes = @BetTypes,
                                  @Bet = @Bet;
                         END;
                         ELSE
                         BEGIN -- Select UnMarked Tickets By BetIds;
                             EXEC [dbo].[Nap_SpecialDelete_UnMarkedTickets_BetIds_Select]
                                  @TransIds = @TransIds
                         END;
                 END;
                 ELSE
                 BEGIN -- Marked;
                     IF @SearchBy = 0
                         BEGIN -- Select Marked Tickets By MatchId
                             EXEC [dbo].[Nap_SpecialDelete_MarkedTickets_MatchId_Select]
                                  @MatchId = @MatchId,
                                  @Duration = @Duration,
                                  @LiveIndicator = @LiveIndicator,
                                  @LiveHomeScore = @LiveHomeScore,
                                  @LiveAwayScore = @LiveAwayScore,
                                  @CurrencyIDs = @CurrencyIDs,
                                  @LicenseeNames = @LicenseeNames,
                                  @BetTypes = @BetTypes,
                                  @Bet = @Bet;
                         END;
                         ELSE
                         BEGIN -- Select Marked Tickets By BetIds;
                             EXEC [dbo].[Nap_SpecialDelete_MarkedTickets_BetIds_Select]
                                  @TransIds = @TransIds
                         END;
                 END;
             SET NOCOUNT OFF;
         END;
GO
