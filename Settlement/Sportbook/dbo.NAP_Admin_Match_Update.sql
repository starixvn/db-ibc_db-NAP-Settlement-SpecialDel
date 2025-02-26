/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Match_Update]
(
    @Command                    VARCHAR(100),
    @MatchID                    INT,
	@DestinationMatchid			INT = NULL,
    @FTHome                     SMALLINT = NULL,
    @FTAway                     SMALLINT = NULL,
    @HTHome                     SMALLINT = NULL,
    @HTAway                     SMALLINT = NULL,
    @BetStatus                  NVARCHAR(50)= NULL,
    @GoalRecord                 VARCHAR(50) = NULL,
    @Action                     VARCHAR(10)         = NULL,
    @FTDone                     BIT = 0,
    @HTDone                     BIT = 0,
    @RowCount                   INT = 0 OUTPUT,
	@Creator 					INT = 0,
	@IsFinalRound               BIT = NULL,
	@IsHTRound					BIT = 0,
	@IsMovedMatch				BIT = 0,
	@HTBetStatus				NVARCHAR(50) = NULL,
	@FTBetStatus				NVARCHAR(50) = NULL,
	@SelectedResources			VARCHAR(MAX) = NULL
	
)
AS   
/*
    Created: Kathy
    Date: 20140213
    Task : Update information into match table (when run settlement)
    DB: DBPRO/bodb02
    Original: Admin_Match_Update

    Revisions:
        - 20140423@Kathy: Modify betstatus value (Offer 1H FGLG) [Redmine:#14449]
        - 20140618@Kathy: Remove PenaltyShootout string, correct betstatus in case match has been refunded [Redmine:#17142]
        - 20140825@Kathy: Only update HT part of goalrecord when calculating HT
        - 20140912@Kathy: Correct betstatus when calculate FT '3x30' match [Redmine:#22399]
        - 20141013@Jamie: Sporting Solution for Tennis [Redmine:#23034]
        - 20150618@Jamie: Offer the option Exclude Corner tickets [Feature #38099]
        - 20150812@Kathy: Add more command for VS sports [Redmine:#40125]
        - 20150918@Johnson: Check status of corner tickets when settle FT [Redmine: #43806]
        - 20151012@Patrick: Reset betstatus for Muay Thai when user do action RefundFull & RefundFT [Redmine: #45356]
        - 20160225@Kathy: Update eventstatus, betstatus when the match is settled
        - 20160315@Patrick: Auto payout [Redmine: #53262]
        - 20160907@bobby: #63765 - Update betstatus when doing refund HT/FT/ALL
        - 20161118@Bobby: #67551 - Update changes for refunding SDT - Abandoned match
        - 20161128@Bobby: #67760 - Implement IS for FGLG bet types
        - 20170215@Kathy: Basketball All-in-One [Redmine:#71372]
        - 20170606@Bobby: 77720 - Implement BetRadar VS League & Nation
        - 20171011@Kathy: Correct GoalRecord value when do instant + cal HT [Redmine:#81308]
        - 20171212@Kathy: Change on Refund page [Redmine:#86890]
        - 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20181016@Vicky: Incorporate Happy 5  [Redmine:#102844]
		- 20190313@Kathy: Change command for refund HT, FT, ALL to avoid wrong replacing SP deployment [Redmine:#109007]
		- 20190411@Kathy: Change command for calculate FGLG to avoid wrong replacing SP deployment [Redmine:#106823]
		- 20190528@Kathy: Do not update SettleTime when cal FGLG & cal corner [Redmine:#113460]
		- 20190425@Sol: Auto Payout Phase 3 [Redmine:#116073]
		- 20190621@Sol: Auto Payout Phase 3 - Change command for Instant Calculation to avoid wrong replacing SP deployment [Redmine:#116073]
		- 20190620@Kathy: Remove betradar corner bettypes [Redmine:#109584
		- 20200122@Helen: Keep FT Score when re-calculating HT Score [Redmine:#127594]
		- 20200306@Sol:	Don't change Event Status to Completed When Calculate HT - [Redmine:#129884]
        - 20200210@Sol: Settlement with Ticket Exclusion for Other Sports - Tennis - [Redmine:#129316]
		- 20200511@Kathy: Remove tennis code [Redmine:#129316]
		- 20200701@Kathy: Incorporate New Bet Types of Basketball - Phase 2 [Redmine:#135846]
		- 20200728@Kathy: update htscore for basketball when HT is done [Redmine:#135846]
		- 20210122@Louisa: Cricket AIO [Redmine:#148870]
		- 20210517@Louisa: Incorporate Saba Soccer PinGoal [Redmine:#155052]
		- 20210930@Louisa: Move running single tickets for E-Sports [Redmine:#159271]
		- 20211108@Louisa: In-house Replicator: Update Action [Redmine:#164393] 
		- 20211215@Kathy: Soccer - Include calculate parlay into calculate single tickets process [Redmine:#166072]
		- 20220629@Louisa: Volleyball AIO [Redmineid:#173862]
		- 20220719@Louisa: Update match.multiple = 1 before calcualte/refund for VSBetradar [Redmine:#175251]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251] 
        - 20230406@Aries: Un-calculate FT Only [Redmine: #146737]
		- 20230704@Louisa:  Integrate Virtual Leap Gaming - VS3 [Redmine:#189854]
		- 20231002@Louisa: Integrate sporttype 58-Bandy [Redmine: #196041]
		- 20240118@Louisa: Integrate VS4 - Cock Fighting [Redmine: #199700]
		- 20240718@Kathy: Implement AiO for Baseball - 8 new bettypes [Redmine:#208026]
		- 20250205@Louisa: Apply SOP for Soccer [Redmine:#216004] 

    Parameters Explanation:
		 @SelectedResources = <Resources>
                                    <Resource Id="00" Home="1" Away="3" /> 
                                    <Resource Id="01" Home="1" Away="2" />
                              </Resources> 

*/
BEGIN
    SET NOCOUNT ON

    DECLARE @Sporttype		INT
			,@eventstatus	VARCHAR(20)
			,@ParentMatchId	INT
			,@NewMatchCode	NVARCHAR(100)
			,@handle		INT

	DECLARE @tmpSelectedRID TABLE(ResourceID VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50))

    SET @BetStatus = ISNULL(@BetStatus, N'')

	SELECT	@ParentMatchId = CASE WHEN ISNULL(m.ChildMatchType,0) = 200 AND m.ParentID IS NOT NULl AND m.sporttype IN (8, 50) THEN m.ParentID ELSE NULL END
			,@sporttype = m.sporttype
	FROM	dbo.match m WITH(NOLOCK)
	WHERE	m.matchid = @MatchID

	IF @IsMovedMatch = 0 AND @ParentMatchId IS NOT NULL -- child match of cricket
		RETURN

	IF @SelectedResources IS NOT NULL AND @Sporttype > 99 --use for 3rd product
	BEGIN
		EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedResources
		INSERT INTO @tmpSelectedRID(ResourceID, HomeValue, AwayValue)
		SELECT Id, Home, Away
		FROM OPENXML(@handle,'Resources/Resource',1) WITH( Id	VARCHAR(20)
															,Home VARCHAR(50)
															,Away VARCHAR(50)
											) AS tbl
		EXEC sp_xml_removedocument @handle

		SELECT TOP(1) 
			 @FTHome = HomeValue
			,@FTAway = AwayValue
  		FROM @tmpSelectedRID sr
  		WHERE sr.ResourceID = '00'

  		SELECT TOP(1)	
			 @HTHome = HomeValue
			,@HTAway = AwayValue
  		FROM @tmpSelectedRID sr
  		WHERE sr.ResourceID = '01' 
	END

    IF @Command = 'NAP_Admin_Settlement_1-UNDO'
    BEGIN
        UPDATE dbo.match WITH(ROWLOCK,UPDLOCK)
		SET  eventstatus	= 'running'
			,finalhomescore = NULL 
			,finalawayscore = NULL
			,hthomescore	= NULL
			,htawayscore	= NULL
			,betstatus		= N''
			,GoalRecord		= ''
			,changetime		= GETDATE(), settleTime = GETDATE()
		WHERE matchid = @MatchID-- and eventstatus = 'completed'
    END
    IF @Command = 'NAP_Admin_Settlement_1-UNDO-FT'
    BEGIN
        UPDATE dbo.match WITH(ROWLOCK,UPDLOCK)
		SET  eventstatus	= 'running'
			,finalhomescore = NULL 
			,finalawayscore = NULL
			,betstatus		= @BetStatus
			,GoalRecord		= @GoalRecord
			,changetime		= GETDATE(), settleTime = GETDATE()
		WHERE matchid = @MatchID-- and eventstatus = 'completed'
    END
    IF @Command = 'NAP_Admin_Settlement_1-CAL'
    BEGIN
        UPDATE dbo.match with (ROWLOCK,UPDLOCK)
        SET
            finalhomescore =  CASE WHEN @action = 'CAL-HT' THEN finalhomescore ELSE @FTHome END
            ,finalawayscore = CASE WHEN @action = 'CAL-HT' THEN finalawayscore ELSE @FTAway END
            ,hthomescore = @HTHome, htawayscore = @HTAway,
        --  betstatus = CASE WHEN @action = 'CAL-FT' AND CHARINDEX('Refund HT;',betstatus)>0 THEN 'Refund HT;' + ISNULL(@betstatus,'') ELSE @betstatus END,
            betstatus = ISNULL(@betstatus,''),
            goalrecord = CASE WHEN @goalrecord IS NULL OR @goalrecord = '' THEN goalrecord
                              WHEN @action = 'CAL-HT' AND ISNULL(GoalRecord,'') <> '' AND CHARINDEX(';',GoalRecord) > 0 THEN REPLACE(GoalRecord,LEFT(GoalRecord,CHARINDEX(';',GoalRecord)),(LEFT(@goalrecord,CHARINDEX(';',@goalrecord)))) -- only update HT part
                              ELSE @goalrecord END,
            eventstatus = CASE	
							WHEN @action = 'CAL' THEN N'completed'
							WHEN @action = 'CAL-FT' AND @HTDone = 1 THEN N'completed'
							ELSE eventstatus END,
            changetime = GETDATE(),
            settleTime = CASE
                            WHEN @action = 'CAL' THEN GETDATE()
                            WHEN @action = 'CAL-FT' THEN GETDATE()
                            ELSE settleTime END
        WHERE matchid = @MatchID

    END
    IF @Command = 'NAP_Admin_Settlement_Refund-All'
    BEGIN

        SELECT @Sporttype = sporttype
        FROM match with(NOLOCK)
        WHERE matchid = @matchid

        IF @Sporttype = 44
        BEGIN
            SET @betstatus = ''
        END

        UPDATE match WITH(ROWLOCK,UPDLOCK)
        SET eventstatus='Completed', ruben=1, finalhomescore=0, finalawayscore=0, hthomescore=0, htawayscore=0
            ,betstatus = 'Refund;' + CASE  WHEN CHARINDEX('Refund;',@betstatus) > 0 THEN REPLACE(@betstatus,'Refund;','')
                                        WHEN CHARINDEX('Refund FT;',@betstatus) > 0 THEN REPLACE(@betstatus,'Refund FT;','')
                                        WHEN CHARINDEX('Refund HT;',@betstatus)>0 THEN REPLACE(@betstatus,'Refund HT;','')
                                        ELSE @betstatus
                                    END
            ,GoalRecord =''
            ,changetime = GETDATE(), settleTime = GETDATE()
        WHERE matchid=@MatchID
       
    END
    IF @Command = 'NAP_Admin_Settlement_Refund-All-Abandoned'
    BEGIN
        SET @betstatus = ISNULL(@betstatus, '')

        SELECT @Sporttype = sporttype
            ,@betstatus = CASE
                                    WHEN CHARINDEX('Refund HT',betstatus) > 0 OR CHARINDEX('Refund;', betstatus) > 0 THEN
                                        'Refund;' + CASE
                                            WHEN CHARINDEX('Refund;',@betstatus) > 0 THEN REPLACE(@betstatus,'Refund;','')
                                            WHEN CHARINDEX('Refund FT;',@betstatus) > 0 THEN REPLACE(@betstatus,'Refund FT;','')
                                            WHEN CHARINDEX('Refund HT;',@betstatus)>0 THEN REPLACE(@betstatus,'Refund HT;','')
                                            ELSE @betstatus
                                        END
                                    ELSE 'Abandoned 1H;' + CASE
                                            WHEN CHARINDEX('Abandoned 2H;',@betstatus) > 0 THEN REPLACE(@betstatus,'Abandoned 2H;','')
                                            WHEN CHARINDEX('Abandoned 1H;',@betstatus) > 0 THEN REPLACE(@betstatus,'Abandoned 1H;','')
                                            ELSE @betstatus
                                        END
                                END
        FROM match with(NOLOCK)
        WHERE matchid = @matchid

        IF @sporttype =  1
        BEGIN

            UPDATE match WITH(ROWLOCK,UPDLOCK)
            SET eventstatus='Completed'
                , ruben             = 1
                , finalhomescore    = CASE WHEN CHARINDEX('Refund',@betstatus) > 0 THEN @FTHome ELSE NULL END
                , finalawayscore    = CASE WHEN CHARINDEX('Refund',@betstatus) > 0 THEN @FTAway ELSE NULL END
                , hthomescore       = CASE WHEN CHARINDEX('Abandoned',@betstatus) > 0 THEN @HTHome ELSE hthomescore END
                , htawayscore       = CASE WHEN CHARINDEX('Abandoned',@betstatus) > 0 THEN @HTAway ELSE htawayscore END
                , betstatus         = @betstatus
                , GoalRecord        = @GoalRecord
                , changetime        = GETDATE(), settleTime = GETDATE()
            WHERE matchid=@MatchID
        END
    END
    IF @Command = 'NAP_Admin_Settlement_Refund-FT'
    BEGIN

        IF ISNULL(@betstatus , '') = ''
        BEGIN
            SET @betstatus = ''
        END

        UPDATE dbo.match WITH(ROWLOCK,UPDLOCK)
        SET finalhomescore=0, finalawayscore=0,
            betstatus = CASE WHEN CHARINDEX('Refund;', betstatus) > 0
                                    THEN betstatus
                             ELSE 'Refund FT;' + CASE WHEN CHARINDEX('Refund HT;',@betstatus) > 0
                                                            THEN REPLACE(@betstatus, 'Refund HT;', '')
                                                    WHEN CHARINDEX('Refund FT;',@betstatus) > 0
                                                            THEN REPLACE(@betstatus, 'Refund FT;', '')
                                                      ELSE @betstatus
                                                 END
                        END
            ,eventstatus = CASE WHEN @HTDone=1 THEN 'Completed' ELSE eventstatus END
            ,changetime  = GETDATE(), settleTime = GETDATE()
        WHERE matchid=@MatchID
              AND @HTDone = 1                  
			  
        --- get rowcount
        SET @RowCount = @@ROWCOUNT
		
    END
    IF @Command = 'NAP_Admin_Settlement_Refund-FT-Abandoned'
    BEGIN

        SET @betstatus = ISNULL(@betstatus, '')

        UPDATE dbo.match WITH(ROWLOCK,UPDLOCK)
        SET finalhomescore      = @FTHome
            , finalawayscore    = @FTAway
            , betstatus         = CASE
                                    WHEN CHARINDEX('Abandoned;', betstatus) > 0 THEN betstatus
                                    ELSE 'Abandoned 2H;' + CASE
                                                            WHEN CHARINDEX('Abandoned 1H;',@betstatus) > 0 THEN REPLACE(@betstatus, 'Abandoned 1H;', '')
                                                            WHEN CHARINDEX('Abandoned 2H;',@betstatus) > 0 THEN REPLACE(@betstatus, 'Abandoned 2H;', '')
                                                            ELSE @betstatus
                                                        END
                        END
            ,eventstatus = CASE WHEN @HTDone=1 THEN 'Completed' ELSE eventstatus END
            ,changetime  = GETDATE()
            ,settleTime = GETDATE()
            ,GoalRecord = @GoalRecord
        WHERE matchid=@MatchID

        --- get rowcount
        SET @RowCount = @@ROWCOUNT
    END
    IF @Command = 'NAP_Admin_Settlement_Refund-HT'
    BEGIN
        UPDATE dbo.match WITH(ROWLOCK,UPDLOCK)
        SET hthomescore=0, htawayscore=0,
            betstatus = CASE WHEN CHARINDEX('Refund;', betstatus) > 0
                                    THEN betstatus
                             ELSE 'Refund HT;' + CASE WHEN CHARINDEX('Refund FT;',betstatus) > 0
                                                            THEN REPLACE(ISNULL(betstatus,''), 'Refund FT;', '')
                                                      ELSE REPLACE(ISNULL(betstatus,''), 'Refund HT;', '')
                                                 END
                        END,
            changetime = GETDATE()
        WHERE matchid=@MatchID

        --- get rowcount
        SET @RowCount = @@ROWCOUNT
    END

    IF @Command IN ('NAP_Admin_Settlement_Parlay', 'NAP_Admin_Settlement_Refund_MP')
    BEGIN
        UPDATE match WITH(ROWLOCK,UPDLOCK) SET multiple=multiple, changetime = GETDATE() WHERE matchid=@MatchID
    END

    IF @Command = 'NAP_Admin_Settlement_SS-CAL'
    BEGIN
        UPDATE dbo.match WITH(ROWLOCK,UPDLOCK)
        SET
            eventstatus = 'Completed',
            changetime = CURRENT_TIMESTAMP,
            settleTime = CURRENT_TIMESTAMP
        WHERE matchid = @MatchID
    END
    IF @Command = 'NAP_Admin_Settlement_VS_181-CAL'
    BEGIN
        UPDATE dbo.VSRaceInfo WITH(ROWLOCK,UPDLOCK)
        SET
            calculate = 1,
            eventstatus = 'Completed',
            betstatus = NULL ,
            changetime = CURRENT_TIMESTAMP
        WHERE EventID = @MatchID

        UPDATE [dbo].[VSOutright] WITH(ROWLOCK,UPDLOCK)
        SET
            eventstatus = 'Completed',
            changetime = CURRENT_TIMESTAMP
        WHERE EventID = @MatchID
    END
    IF @Command = 'NAP_Admin_Settlement_VS_181-Refund'
    BEGIN
        UPDATE dbo.VSRaceInfo WITH(ROWLOCK,UPDLOCK)
        SET
            betstatus = 'Refund',
            eventstatus = 'Completed',
            calculate = 1,
            changetime = CURRENT_TIMESTAMP
        WHERE EventID = @MatchID

        UPDATE [dbo].[VSOutright] WITH(ROWLOCK,UPDLOCK)
        SET
            eventstatus = 'Completed',
            changetime = CURRENT_TIMESTAMP
        WHERE EventID = @MatchID
    END
   
    IF @Command = 'instant'
    BEGIN

        SET @betstatus = ISNULL(@betstatus, '')

        SELECT @Sporttype   = sporttype
        FROM dbo.match WITH(NOLOCK)
        WHERE matchid = @matchid

        IF @sporttype =  1
        BEGIN
            UPDATE dbo.match WITH(ROWLOCK,UPDLOCK)
            SET betstatus   = @betstatus
				,changetime = GETDATE()
            WHERE matchid   = @MatchID
        END
    END

	IF @Command = 'NAP_Admin_Settlement_VS_BetRadar-REFUND'
    BEGIN
        UPDATE dbo.match WITH(ROWLOCK, UPDLOCK)
            SET eventstatus = 'Completed'
                ,betstatus = 'Refund'
                ,changetime = CURRENT_TIMESTAMP
                ,settletime = CURRENT_TIMESTAMP
                ,finalhomescore=0
                ,finalawayscore=0
                ,hthomescore = 0
                ,htawayscore = 0
        WHERE   matchid = @matchid
    END

	---Virtual soccer/tennis
	IF @Command = 'NAP_Admin_Settlement_VS_180-CAL'
    BEGIN
        UPDATE  dbo.match WITH(ROWLOCK, UPDLOCK)
            SET finalhomescore = @fthome
                ,finalawayscore = @ftaway
                ,eventstatus = 'Completed'
                ,changetime = CURRENT_TIMESTAMP
                ,settletime = CURRENT_TIMESTAMP
        WHERE   matchid = @matchid
    END

	IF @Command = 'NAP_Admin_Settlement_VS_180-REFUND'
    BEGIN
        UPDATE dbo.match WITH(ROWLOCK, UPDLOCK)
            SET eventstatus = 'Completed'
                ,betstatus = 'Refund'
                ,changetime = CURRENT_TIMESTAMP
                ,settletime = CURRENT_TIMESTAMP
                ,finalhomescore=0
                ,finalawayscore=0
        WHERE   matchid = @matchid
    END
	---/End Virtual soccer/tennis

    IF @Command = 'completed'
    BEGIN	
		SET @eventstatus = N'completed'

		IF @action LIKE 'REFUND%'
		BEGIN
       		SELECT @betstatus = CASE 
									WHEN @Action = 'REFUND' THEN N'Refund'
									WHEN @Action = 'REFUND-FT' THEN N'Refund FT'
									ELSE ''
								END

			IF @sporttype IN (180,188)
				SELECT	@fthome = 0
						,@ftaway = 0
			ELSE IF @Sporttype BETWEEN 190 AND 197
				SELECT	@fthome = 0
						,@ftaway = 0
						,@HTHome = 0
						,@HTAway = 0
    	 END
		 
        UPDATE  dbo.match WITH(ROWLOCK, UPDLOCK)
            SET eventstatus     = COALESCE(@eventstatus, eventstatus)
                ,betstatus      = COALESCE(@betstatus, betstatus)
				,finalhomescore	= COALESCE(@fthome, finalhomescore)
				,finalawayscore	= COALESCE(@ftaway, finalawayscore)
				,hthomescore	= COALESCE(@hthome, hthomescore)
				,htawayscore	= COALESCE(@htaway, htawayscore)
                ,changetime     = GETDATE()
                ,settletime     = GETDATE()
				,multiple		= CASE WHEN @Sporttype BETWEEN 190 AND 197 OR @Sporttype = 188 THEN 1 ELSE multiple END
        WHERE   matchid = @matchid
    END

    IF @Command = 'profile'
    BEGIN
		DECLARE @ruben TINYINT

        SELECT @Sporttype   = sporttype
        FROM dbo.match WITH(NOLOCK)
        WHERE matchid = @matchid

		IF @IsFinalRound = 1
		BEGIN
			IF @action = 'REFUND'
           		SELECT @eventstatus        = N'completed'
	                   ,@ruben             = 1
	                   ,@betstatus         = CASE WHEN @Sporttype IN ( 5, 6 ) 
                                                    THEN CASE WHEN CHARINDEX('Refund;',@betstatus) > 0 THEN @betstatus ELSE 'Refund;' + @betstatus END
                                                ELSE 'Refund;' END
	                   
	        IF @action = 'UNDO'
			BEGIN
           		SELECT @eventstatus         = N'running'
	                   ,@FTHome     		= -1
	                   ,@FTAway     		= -1
				
				IF @IsHTRound = 1 OR @Sporttype NOT IN (2,58)
					SELECT	 @HTHome = -1
							,@HTAway = -1
			END
	                   
	        IF @action = 'CAL'
	        	SELECT @eventstatus			= N'completed'
	        
	        UPDATE  dbo.match WITH(ROWLOCK, UPDLOCK)
            SET eventstatus     = COALESCE(@eventstatus, eventstatus)
                ,ruben          = COALESCE(@ruben, ruben)
                ,finalhomescore = CASE WHEN @FTHome < 0 THEN NULL ELSE COALESCE(@FTHome, finalhomescore) END
                ,finalawayscore = CASE WHEN @FTAway < 0 THEN NULL ELSE COALESCE(@FTAway, finalawayscore) END
                ,hthomescore    = CASE 
									WHEN @HTHome < 0 THEN NULL
									WHEN @IsHTRound = 1 OR @Sporttype NOT IN (2,58) THEN COALESCE(@HTHome, hthomescore)
									ELSE hthomescore 
								END
                ,htawayscore    = CASE 
									WHEN @HTAway < 0 THEN NULL
									WHEN @IsHTRound = 1 OR @Sporttype NOT IN (2,58) THEN COALESCE(@HTAway, htawayscore) 
									ELSE htawayscore 
								END
                ,betstatus      = COALESCE(@betstatus, betstatus)
                ,changetime     = GETDATE()
                ,settletime     = GETDATE()
            WHERE matchid = @matchid
        END
        ELSE IF @IsFinalRound = 0 AND @Sporttype IN (1,2,5,6,58)
        BEGIN
			IF (@IsHTRound = 1 OR @Sporttype NOT IN (2,58)) AND @Action = 'UNDO'
				SELECT	@HTHome = -1
						,@HTAway = -1

            UPDATE  dbo.match WITH(ROWLOCK, UPDLOCK)
            SET betstatus = COALESCE(@betstatus, betstatus)
				,hthomescore    = CASE 
									WHEN @HTHome < 0 THEN NULL
									WHEN @IsHTRound = 1 OR @Sporttype NOT IN (2,58) THEN COALESCE(@HTHome, hthomescore)
									ELSE hthomescore 
								END
                ,htawayscore    = CASE 
									WHEN @HTAway < 0 THEN NULL
									WHEN @IsHTRound = 1 OR @Sporttype NOT IN (2,58) THEN COALESCE(@HTAway, htawayscore) 
									ELSE htawayscore 
								END
				,changetime = GETDATE()
            WHERE matchid = @matchid
        END
    END

	IF @Command = 'NAP_Admin_Settlement-MoveTicket'
	BEGIN
		SELECT @NewMatchCode = 'betdaq' + m.matchcode
		FROM dbo.match m WITH(NOLOCK)
		WHERE m.matchid = @DestinationMatchid
		
		--Update old match
		UPDATE dbo.match WITH(ROWLOCK,UPDLOCK)
		SET matchcode = @NewMatchCode
			,changetime = GETDATE()
		WHERE matchid = @MatchId
		
	END

	IF @Command = 'NAP_Admin_Settlement-SaveScore'
	BEGIN
		UPDATE dbo.match WITH(ROWLOCK,UPDLOCK)
		SET  finalhomescore	 = ISNULL(@FTHome ,finalhomescore)
			 ,finalawayscore = ISNULL(@FTAway, finalawayscore) 
			 ,hthomescore	 = ISNULL(@HTHome, hthomescore) 
			 ,htawayscore	 = ISNULL(@HTAway, htawayscore) 
			 ,GoalRecord     = ISNULL(@GoalRecord,GoalRecord)
             ,changetime	= GETDATE()
		WHERE matchid = @MatchId
			AND eventstatus <> N'completed'
	END

END
GO
