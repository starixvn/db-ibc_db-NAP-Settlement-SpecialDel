/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_SD_SetExtraInfoAbnormalBet] 
(
	@IsAbnormalBet	BIT = 0,
	@IsMark			VARCHAR(10) = 'void',
	@ExtraInfo		VARCHAR(1000)
)
RETURNS VARCHAR(1000)
/*
	Created: 20190219@Alan
	Task: Abnormal Bet
	DB: DBTXN.BODB02
	Original:
	Revisions: 
	- 20190219@Alan: Support New Ticket Status Abnormal Bet [106654]

	Params:
	@IsMark: - 'recover': Recover Abnormal Bet Tickets
			 - 'void': Void Abnormal Bet Tickets
*/ 

AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result VARCHAR(1000) = @ExtraInfo
	DECLARE @XmlData XML = CAST(ISNULL(@ExtraInfo, '') AS XML)

	-- Add the T-SQL statements to compute the return value here
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

	-- Return the result of the function
	RETURN @Result
END
GO

