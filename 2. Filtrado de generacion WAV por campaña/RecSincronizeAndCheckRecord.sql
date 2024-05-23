USE [MMProDat]
GO

/****** Object:  StoredProcedure [dbo].[RecSincronizeAndCheckRecord]    Script Date: 02/14/2024 23:09:57 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


--exec RecSincronizeAndCheckRecord '1001','SIP'

CREATE PROCEDURE [dbo].[RecSincronizeAndCheckRecord](@IdDevice varchar(50), @Technology varchar (50))
AS

set nocount  on 	

Declare @Result 	   VarChar( 100)
Declare @RecordOnly        Varchar (1)
Declare @InteractionId     varchar (255)
Declare @TelAgente	   varchar (100)
Declare @AttentionNumber   numeric(5, 0)

Declare @Campaign varchar(100)
Declare @VCCValidate varchar(100)

Select @InteractionId = ''

if LTRIM(RTRIM(@Technology)) = '' 
  begin
	Select @TelAgente = @IdDevice
  end
else
  begin
	Select @TelAgente = @Technology + '%' + @IdDevice 
  end

select top 1 @InteractionId = Id, @AttentionNumber = Section,
	@Campaign = InteractionActorDetail.Campaign, @VCCValidate = InteractionActorDetail.VirtualCC 
  from WFUsuLog0227 (nolock) , InteractionActorDetail (nolock), 
  			UserAddressesActive (nolock), UserStates (nolock)
 where Address = @TelAgente
   and IdApplication = 'BarAgent'
   and IdUser	= F1Usua00920227
   And IdChannel = 'TAPI'
   AND (Estado0227 = UserStates.IdState AND (UserStates.VCC = 'SYSTEM' OR WfUsuLog0227.VirtualCC = UserStates.VCC))
   and Actor = F1Usua00920227
   and WFUsuLog0227.VirtualCC = InteractionActorDetail.VirtualCC
   and UserAddressesActive.VCC = InteractionActorDetail.VirtualCC
   and Type = 'TAPI' 
   
order by TimeStamp desc

If LTRIM(RTRIM(@InteractionId)) = ''
   Begin
	Select @RecordOnly = Valor_0206
	  From Parametr0206 (nolock)
	 Where Clave10206 = 'RECORD'
	   and Clave20206 = 'RECORDONLY'
	   and Clave30206 = 'Flag'

	IF isNull(@RecordOnly,'N') = 'S'
	   Begin
		Select '1~'
	   End
	Else
	   Begin
		Select '0~'
	   End
   End
Else
   Begin
   IF (@VCCValidate in ('womventas') AND @Campaign in ('inbound_emergia','inbound_interactivo','inbound_apex','inbound_gss','inbound_marketmix'))
		BEGIN
          select @AttentionNumber = @AttentionNumber + 900
		END

	Select '1~' + @InteractionId + '~' + Convert(varchar(10), @AttentionNumber) 
   End

GO

