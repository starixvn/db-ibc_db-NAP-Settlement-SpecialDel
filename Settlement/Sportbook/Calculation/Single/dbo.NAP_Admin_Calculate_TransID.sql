/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_TransID]
    @transIds           VARCHAR(MAX)
    
AS
/*
    Created by: 20180801@Vicky
    Task: Settlement  
    DB: DBTRANS.BODB02
    
    Revisions:
        - 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
        
    Param's Explanation:  
           
        @transIds = '<root>
                        <r t="104730774034" m="1"/>
                        <r t="104729373985" m="0" ot="1"/>
                    </root>'
                    t:  transid
                    m:  modds     
                    ot: oddstype: 1: DECIMAL ONLY   
*/
BEGIN
	
    SET NOCOUNT ON

    DECLARE @tempTrans TABLE (TransID BIGINT, modds SMALLMONEY, oddstype SMALLINT)
    DECLARE @handle 			INT
    		,@modds 			SMALLMONEY
			,@commWinRate       SMALLMONEY
			,@commLostRate      SMALLMONEY
    		,@odds				SMALLMONEY

    ---parse XML
    EXEC sp_xml_preparedocument @handle OUTPUT, @transIds
    INSERT INTO @tempTrans(TransID, modds, oddstype)
    SELECT t, m, ot
    FROM OPENXML(@handle,'root/r',1) WITH(t   BIGINT
                                         ,m   SMALLMONEY
                                         ,ot  TINYINT
                                    ) tbl
	EXEC sp_xml_removedocument @handle
	
	--IF @action = 'CAL'
    	UPDATE  b
            SET @modds = sr.modds,--END @modds
               @commWinRate = CASE comstatus -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
                                    WHEN '0' THEN 1
                                    WHEN '1' THEN 0
                                    ELSE 1 END,
               @commLostRate = CASE comstatus
                                    WHEN '0' THEN 1
                                    WHEN '1' THEN 2
                                    ELSE 1 END,
               @odds = (CASE WHEN b.odds < 0 THEN 1 
               				 WHEN sr.oddstype IS NOT NULL AND sr.oddstype = 1 THEN b.odds - 1 ----/*DECIMAL ONLY*/
	                		 ELSE b.odds END),
            ----------------------------------------------------------------------------------------------------------------
			modds = @modds,               			
            WinLost = CASE
                    WHEN @modds >  0.25 THEN actual_stake + stake * @odds
                    WHEN @modds =  0.25 THEN actual_stake + stake * @odds * 0.5
                    WHEN @modds =  0    THEN actual_stake
                    WHEN @modds = -0.25 THEN actual_stake * 0.5
                    WHEN @modds < -0.25 THEN 0
                    END,
            aWinLost = CASE
                    WHEN @modds >  0.25 THEN stake * @odds * -apositiontaking
                    WHEN @modds =  0.25 THEN stake * @odds * -apositiontaking * 0.5
                    WHEN @modds =  0    THEN 0
                    WHEN @modds = -0.25 THEN actual_stake * apositiontaking * 0.5
                    WHEN @modds < -0.25 THEN actual_stake * apositiontaking
                    END,
            mWinLost = CASE
                    WHEN @modds >  0.25 THEN stake * @odds * -mpositiontaking
                    WHEN @modds =  0.25 THEN stake * @odds * -mpositiontaking * 0.5
                    WHEN @modds =  0    THEN 0
                    WHEN @modds = -0.25 THEN actual_stake * mpositiontaking * 0.5
                    WHEN @modds < -0.25 THEN actual_stake * mpositiontaking
                    END,
            sWinLost = CASE
                    WHEN @modds >  0.25 THEN stake * @odds * -spositiontaking
                    WHEN @modds =  0.25 THEN stake * @odds * -spositiontaking * 0.5
                    WHEN @modds =  0    THEN 0
                    WHEN @modds = -0.25 THEN actual_stake * spositiontaking * 0.5
                    WHEN @modds < -0.25 THEN actual_stake * spositiontaking
                    END,

            PlayerComm = CASE
                    WHEN @modds >  0.25 THEN @commWinRate * playerdiscount * stake
                    WHEN @modds =  0.25 THEN @commWinRate * playerdiscount * stake * 0.5
                    WHEN @modds =  0    THEN 0
                    WHEN @modds = -0.25 THEN @commLostRate * playerdiscount * stake * 0.5
                    WHEN @modds < -0.25 THEN @commLostRate * playerdiscount * stake
                    END,
            Comm = CASE
                    WHEN @modds >  0.25 THEN @commWinRate * discount * stake * (1-apositiontaking)
                    WHEN @modds =  0.25 THEN @commWinRate * discount * stake * (1-apositiontaking) * 0.5
                    WHEN @modds =  0    THEN 0
                    WHEN @modds = -0.25 THEN @commLostRate * discount * stake * (1-apositiontaking) * 0.5
                    WHEN @modds < -0.25 THEN @commLostRate * discount * stake * (1-apositiontaking)
                    END,
            aComm = CASE
                    WHEN @modds >  0.25 THEN @commWinRate * adiscount * stake * (1-(mpositiontaking+apositiontaking))
                    WHEN @modds =  0.25 THEN @commWinRate * adiscount * stake * (1-(mpositiontaking+apositiontaking)) * 0.5
                    WHEN @modds =  0    THEN 0
                    WHEN @modds = -0.25 THEN @commLostRate * adiscount * stake * (1-(mpositiontaking+apositiontaking)) * 0.5
                    WHEN @modds < -0.25 THEN @commLostRate * adiscount * stake * (1-(mpositiontaking+apositiontaking))
                    END,
            sComm = CASE
                    WHEN @modds >  0.25 THEN @commWinRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
                    WHEN @modds =  0.25 THEN @commWinRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * 0.5
                    WHEN @modds =  0    THEN 0
                    WHEN @modds = -0.25 THEN @commLostRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * 0.5
                    WHEN @modds < -0.25 THEN @commLostRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
                    END,
            Status = CASE
                    WHEN @modds > 0 THEN 'WON'
                    WHEN @modds = 0 THEN 'DRAW'
                    WHEN @modds < 0 THEN 'LOSE'
                    END,
            StatusID = CASE
                    WHEN @modds > 0 THEN 112 --WON
                    WHEN @modds = 0 THEN 111 --DRAW
                    WHEN @modds < 0 THEN 113 --LOSE
                    END,
            ruben=1
    	FROM @tempTrans sr
        	INNER JOIN dbo.bettrans b ON  sr.transid = b.transid
   
    RETURN
END
GO