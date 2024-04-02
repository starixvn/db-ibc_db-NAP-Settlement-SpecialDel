/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_SpecialDel_CheckMatchIDwithRefno]
    @MatchID int
    ,@FromRefno bigint --transid
    ,@ToRefno bigint --transid
    ,@Type SMALLINT = 0
    ,@ErrMsg NVARCHAR(200) = '' OUTPUT
    ,@ErrCode INT = 0 OUTPUT
AS
BEGIN
/*
    Created by: 
    Date: 20110906
    Task: check constraint between refno and matchid
    DB: DBTXN.BODB02    
    Original: 
    
    Revisions:
        - 20110908@Jamie: correct sp according to business rule    
        - 20110914@Jamie: correct sp to cover case of @FromRefno=@ToRefno
        - 20120829@Elodie: Check if the match belongs to virtual sport
                           Change DB053 server instead of DB052 server
        - 20131011@Elodie: Add HR Fixed Odds [Redmine:#6505]        
        - 20150210@Kathy:  check if tickets have been moved to match14, bettrans14 [Redmine:#30298] 
        - 201507014@Dominic: Integrate Metric Gaming - Superlive product into the Special Delete site - Redmine: #38200
        - 20150922@Kathy: Add more Type value to support BetTrade transaction [Redmine:#43233]
        - 20170405@Kent: Integrate Cash-out [Redmine:#72059]
		- 20181122@Alan: Incorporate Happy 5 into Number Game [102845]
		- 20211213@Max: [TVS] Integrate new Cash Out model [Redmine: #165097]
    
    Param's Explanation:    
        - @Type: sports type
            0: Sportsbook
            1: Virtual sports
            2: Number Game
            3: Live Casino
            4: BetTrade
            5: CashOut
*/
    SET NOCOUNT ON
    DECLARE @totalRecord INT, @Sporttype int
        
    select @Sporttype = sporttype
    from match with (NOLOCK)
    where matchid = @MatchID
    
    IF @Sporttype not between 1 and 99 AND @Sporttype <> 154 AND @Type IN (0, 4, 5)
    BEGIN 
        SET @ErrCode = 2
        SET @ErrMsg ='This MatchID doesn''t belong to sportbook.' 
        RETURN
    END 
    
    IF @Sporttype not between 180 and 186 AND @Type = 1
    BEGIN 
        SET @ErrCode = 3
        SET @ErrMsg ='This MatchID doesn''t belong to virtual sports.' 
        RETURN
    END 
    
    IF @Type = 2 AND @Sporttype <> 161 AND @Sporttype <> 164
    BEGIN 
        SET @ErrCode = 4
        SET @ErrMsg ='This MatchID doesn''t belong to number game.' 
        RETURN
    END 
    
    IF @Sporttype <> 162 AND @Type = 3
    BEGIN 
        SET @ErrCode = 5
        SET @ErrMsg ='This MatchID doesn''t belong to live casino.' 
        RETURN
    END 
    
    SELECT @totalRecord = count(1)
    FROM
    (    SELECT 1 Row
        FROM dbo.bettrans WITH (NOLOCK)        
        WHERE transid IN (@FromRefno,@ToRefno)
            AND matchid = @MatchID   
			AND betdaqid = CASE WHEN @Type = 5 THEN -2 ELSE betdaqid END

        UNION ALL
        SELECT 1 Row
        FROM dbo.translog WITH (NOLOCK)        
        WHERE translogid IN (@FromRefno,@ToRefno)
            AND eventid = @MatchID    
    ) tmp
    
    IF @FromRefno=@ToRefno
    BEGIN
        IF @totalRecord <> 1 
        BEGIN
            IF EXISTS (SELECT TOP 1 1 FROM dbo.bettrans14 WITH(NOLOCK) WHERE matchid = @MatchId AND (refno IN (@FromRefno, @ToRefno) OR transid IN (@FromRefno, @ToRefno)))
                SELECT @ErrCode= 6 --  harcode in web
                    ,@ErrMsg='Tickets have been moved.'
            ELSE
                SELECT @ErrCode=1
                    ,@ErrMsg='You have entered an invalid matchId or refno.'
        END
    END
    ELSE IF @totalRecord <> 2 
        BEGIN
            IF EXISTS (SELECT TOP 1 1 FROM dbo.bettrans14 WITH(NOLOCK) WHERE matchid = @MatchId AND (refno IN (@FromRefno, @ToRefno) OR transid IN (@FromRefno, @ToRefno)))
                SELECT @ErrCode= 6 --  harcode in web
                    ,@ErrMsg='Tickets have been moved.'
            ELSE
                SELECT @ErrCode=1
                    ,@ErrMsg='You have entered an invalid matchId or refno.'
        END
    
    SET NOCOUNT OFF
END
GO