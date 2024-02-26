/*<info serverAlias="DBTXN-bodb02,DBACC-bodb02,DBAGE-bodb02" executers="" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_SD_SetExtraInfoAbnormalBet] 
(
	@IsAbnormalBet	TINYINT = 0,
	@IsMark			VARCHAR(10) = 'void',
	@ExtraInfo		VARCHAR(1000),
	@SportType		TINYINT,
	@BetType		SMALLINT
)
RETURNS VARCHAR(1000)
/*
	Created: 20190219@Alan
	Task: Abnormal Bet
	DB: DBTXN.BODB02
	Original:
	Revisions: 
	- 20190219@Alan: Support New Ticket Status Abnormal Bet [106654]
	- 20211124@Max: [TVS] Void abnormal bet of parlay [Redmine: #161337]
	- 20240221@Max: [TVS] Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]

	Params:
	@IsMark: - 'recover': Recover Abnormal Bet Tickets
			 - 'void': Void Abnormal Bet Tickets

	-- Change type to use for void abnormal bet Mix Parlay
	@IsAbnormalBet:
		- 0: Not abnormal
		- 1: Abnormal Bet exclude Mix Parlay (Main)
		- 2: Abnormal Bet Mix Parlay (Main)
*/ 

AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result VARCHAR(1000)
	DECLARE @XmlData XML = CAST(ISNULL(@ExtraInfo, '') AS XML)

	-- Add the T-SQL statements to compute the return value here
	IF @IsAbnormalBet <> 2
	BEGIN
		IF(	@SportType NOT BETWEEN 1 AND 99 OR 
			@BetType IN (10,29,38,2799,10449,901,902,903,904,911,912,913,914,801,803,804,805,806))
		BEGIN
			SET @Result = @ExtraInfo
		END
		ELSE
		BEGIN
			IF(@IsAbnormalBet = 1 AND @IsMark = 'void')
			BEGIN		
				-- Extend Abnormal Bet
				IF(@XmlData.exist('/p1') = 1)
				BEGIN
					SET @XmlData.modify('insert(attribute ab {"1"}) into (/p1)[1]')
				END
				ELSE
				BEGIN
					SET @XmlData.modify('insert <p1 ab="1" /> as last into (/)[1]')
				END	
			END
			-- Remove Abnormal Bet
			ELSE
			BEGIN
				SET @XmlData.modify('delete (/p1/@ab)[1]')
				SET @XmlData.modify('delete //p1[empty(node()) and empty(@*)]')
			END

			SET @Result = CAST(@XmlData AS VARCHAR(1000))
		END
	END
	ELSE IF @IsAbnormalBet = 2
	BEGIN
		IF(@IsAbnormalBet = 2 AND @IsMark = 'void')
		BEGIN		
			-- Extend Abnormal Bet
			IF(@XmlData.exist('/p1') = 1)
			BEGIN
				SET @XmlData.modify('insert(attribute ab {"1"}) into (/p1)[1]')
			END
			ELSE
			BEGIN
				SET @XmlData.modify('insert <p1 ab="1" /> as last into (/)[1]')
			END	
		END
		-- Remove Abnormal Bet
		ELSE
		BEGIN
			SET @XmlData.modify('delete (/p1/@ab)[1]')
			SET @XmlData.modify('delete //p1[empty(node()) and empty(@*)]')
		END

		SET @Result = CAST(@XmlData AS VARCHAR(1000))
	END

	-- Return the result of the function
	RETURN @Result
END
GO

