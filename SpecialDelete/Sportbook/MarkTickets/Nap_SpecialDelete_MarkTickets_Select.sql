
/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Nap_SpecialDelete_MarkTickets_Select] @Status          SMALLINT     = 0,
                                                             @SearchBy        SMALLINT     = 0,
                                                             @MatchId         INT          = 0,
                                                             @FromTransId     BIGINT       = 0,
                                                             @ToTransId       BIGINT       = 0,
                                                             @Duration        XML          = NULL,
                                                             @LiveIndicator   INT          = 0,
                                                             @LiveHomeScore   SMALLINT     = NULL,
                                                             @LiveAwayScore   SMALLINT     = NULL,
                                                             @CurrencyIDs     VARCHAR(MAX) = NULL,
                                                             @LicenseeNames   VARCHAR(MAX) = NULL,
                                                             @BetTypes        XML          = NULL,
                                                             @TransIds        VARCHAR(MAX) = NULL,
                                                             @InvalidTransIds VARCHAR(MAX) = '' OUTPUT,
                                                             @MovedTransIds   VARCHAR(MAX) = '' OUTPUT,
                                                             @MarkedTransIds  VARCHAR(MAX) = '' OUTPUT
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
		- 20190325@Alan: - Mark Ticket for Settlement Exclusion	
*/

         BEGIN
             SET NOCOUNT ON;
             IF @Status = 0
                 BEGIN -- Not Marked
                     IF @SearchBy = 0
                         BEGIN -- Select UnMarked Tickets By MatchId
                             EXEC [dbo].[Nap_SpecialDelete_UnMarkedTickets_MatchId_Select]
                                  @MatchId = @MatchId,
                                  @FromTransId = @FromTransId,
                                  @ToTransId = @ToTransId,
                                  @Duration = @Duration,
                                  @LiveIndicator = @LiveIndicator,
                                  @LiveHomeScore = @LiveHomeScore,
                                  @LiveAwayScore = @LiveAwayScore,
                                  @CurrencyIDs = @CurrencyIDs,
                                  @LicenseeNames = @LicenseeNames,
                                  @BetTypes = @BetTypes;
                         END;
                         ELSE
                         BEGIN -- Select UnMarked Tickets By BetIds;
                             EXEC [dbo].[Nap_SpecialDelete_UnMarkedTickets_BetIds_Select]
                                  @TransIds = @TransIds,
                                  @InvalidTransIds = @InvalidTransIds OUTPUT,
                                  @MovedTransIds = @MovedTransIds OUTPUT,
                                  @MarkedTransIds = @MarkedTransIds OUTPUT;
                         END;
                 END;
                 ELSE
                 BEGIN -- Marked;
                     IF @SearchBy = 0
                         BEGIN -- Select Marked Tickets By MatchId
                             EXEC [dbo].[Nap_SpecialDelete_MarkedTickets_MatchId_Select]
                                  @MatchId = @MatchId,
                                  @FromTransId = @FromTransId,
                                  @ToTransId = @ToTransId,
                                  @Duration = @Duration,
                                  @LiveIndicator = @LiveIndicator,
                                  @LiveHomeScore = @LiveHomeScore,
                                  @LiveAwayScore = @LiveAwayScore,
                                  @CurrencyIDs = @CurrencyIDs,
                                  @LicenseeNames = @LicenseeNames,
                                  @BetTypes = @BetTypes;
                         END;
                         ELSE
                         BEGIN -- Select Marked Tickets By BetIds;
                             EXEC [dbo].[Nap_SpecialDelete_MarkedTickets_BetIds_Select]
                                  @TransIds = @TransIds,
                                  @InvalidTransIds = @InvalidTransIds OUTPUT;
                         END;
                 END;
             SET NOCOUNT OFF;
         END;
GO
