USE [HistoricalData]
GO

/****** Object:  StoredProcedure [dbo].[RepSaveFile]    Script Date: 02/14/2024 23:09:29 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE  PROCEDURE [dbo].[RepSaveFile] (@Id VarChar(100), @Section Numeric(5, 0), @RelativePath VarChar(500),
										@Format VarChar(50), @ContentType VarChar(50), @FileSize Numeric(18, 0), 
										@FileName VarChar(256), @MD5 VarChar(50), @TmStmp DateTime )
AS

	SET NOCOUNT ON

	--Validacion Toque WAV

	IF @Section >= 900
	BEGIN
		SELECT @Section = @Section - 900
	END

	--Verifico si esta habilitada Replicacion.
	Declare @EnableRep Varchar(1)
	
	Select @EnableRep  = AuxStr0002 
	From MMProdat.dbo.Codigos_0252 (Nolock)
	Where F1TiCo02510252 = 'SOA'	
	  And Codigo0252 = 'Replication'

	Select @EnableRep = IsNull(@EnableRep,'0')
	
	
	If (@EnableRep = 0)
	Begin	
		Insert Into InteractionMultimediaParts (Id, Section, Part, RelativePath, Format, ContentType, FileSize, FileName, MD5, TmStmp)
		Output inserted.Part
		Select @Id, @Section, Count(*) + 1, @RelativePath, @format, @contenttype, @FileSize, @FileName, @MD5, @tmstmp 
		From InteractionMultimediaParts (nolock)								
		Where [Id] = @Id 
		AND   [Section] = @Section;
	End
	Else
	Begin
		Declare @HndDialog UniqueIdentifier
		Declare @Message nVarchar(2048)		
	
		Declare @IMMParts Table(Part Numeric(5,0));
		Declare @Part Numeric(5,0)

		Insert Into InteractionMultimediaParts (Id, Section, Part, RelativePath, Format, ContentType, FileSize, FileName, MD5, TmStmp)
		Output inserted.Part into @IMMParts
		Select @Id, @Section, Count(*) + 1, @RelativePath, @format, @contenttype, @FileSize, @FileName, @MD5, @tmstmp 
		From InteractionMultimediaParts (nolock)
		Where [Id] = @Id 
		AND   [Section] = @Section;		
		
		Select @Part = Part From @IMMParts		
		Select @Message = Convert(nVarchar(2048), (Select @Id 'Id', @Section 'Section', @Part 'Part', @RelativePath 'RelativePath', @format 'Format', 
													@contenttype 'ContentType', @FileSize 'FileSize', @FileName 'FileName', @MD5 'MD5', @tmstmp 'TmStmp' FOR XML PATH ('Params'), TYPE));

		Exec SSBSendToHistorical N'//InConcertCC.com/Interaction/SendToReplicationService', N'//InConcertCC.com/Interaction/ReceiveInReplicationService',
							 N'//InConcertCC.com/Interaction/Replication', N'//InConcertCC.com/Interaction/MsgTypeMultimediaPart', @Message, 1, @HndDialog		
							 
		Select @Part
	End
	SET NOCOUNT OFF
GO

