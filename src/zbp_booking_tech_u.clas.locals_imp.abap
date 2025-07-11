CLASS lhc_Booking DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS update FOR MODIFY
      IMPORTING entities FOR UPDATE Booking.

    METHODS delete FOR MODIFY
      IMPORTING keys FOR DELETE Booking.

    METHODS read FOR READ
      IMPORTING keys FOR READ Booking RESULT result.

    METHODS rba_Travel FOR READ
      IMPORTING keys_rba FOR READ Booking\_Travel FULL result_requested RESULT result LINK association_links.

    TYPES tt_booking_failed   TYPE TABLE FOR FAILED   zhru_i_booking.
    TYPES tt_booking_reported TYPE TABLE FOR REPORTED zhru_i_booking.

    METHODS map_messages
      IMPORTING
        cid          TYPE string OPTIONAL
        travel_id    TYPE /dmo/travel_id OPTIONAL
        booking_id   TYPE /dmo/booking_id OPTIONAL
        messages     TYPE /dmo/t_message
      EXPORTING
        failed_added TYPE abap_bool
      CHANGING
        failed       TYPE tt_booking_failed
        reported     TYPE tt_booking_reported.

ENDCLASS.

CLASS lhc_Booking IMPLEMENTATION.

  METHOD update.

    DATA: messages TYPE /dmo/t_message,
          booking  TYPE /dmo/booking,
          bookingx TYPE /dmo/s_booking_inx.

    LOOP AT entities ASSIGNING FIELD-SYMBOL(<booking>).

      booking = CORRESPONDING #( <booking> MAPPING FROM ENTITY ).

      bookingx-_intx       = CORRESPONDING #( <booking> MAPPING FROM ENTITY ).
      bookingx-booking_id  = <booking>-BookingID.
      bookingx-action_code = /dmo/if_flight_legacy=>action_code-update.

      CALL FUNCTION '/DMO/FLIGHT_TRAVEL_UPDATE'
        EXPORTING
          is_travel   = VALUE /dmo/s_travel_in( travel_id = <booking>-travelid )
          is_travelx  = VALUE /dmo/s_travel_inx( travel_id = <booking>-travelid )
          it_booking  = VALUE /dmo/t_booking_in( ( CORRESPONDING #( booking ) ) )
          it_bookingx = VALUE /dmo/t_booking_inx( ( bookingx ) )
        IMPORTING
          et_messages = messages.

      map_messages(
        EXPORTING
          cid        = <booking>-%cid_ref
          travel_id  = <booking>-travelid
          booking_id = <booking>-bookingid
          messages   = messages
        CHANGING
          failed   = failed-booking
          reported = reported-booking ).
    ENDLOOP.
  ENDMETHOD.

  METHOD delete.
    DATA messages TYPE /dmo/t_message.

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<booking>).

      CALL FUNCTION '/DMO/FLIGHT_TRAVEL_UPDATE'
        EXPORTING
          is_travel   = VALUE /dmo/s_travel_in( travel_id = <booking>-travelid )
          is_travelx  = VALUE /dmo/s_travel_inx( travel_id = <booking>-travelid )
          it_booking  = VALUE /dmo/t_booking_in( ( booking_id = <booking>-bookingid ) )
          it_bookingx = VALUE /dmo/t_booking_inx( ( booking_id  = <booking>-bookingid
                                                    action_code = /dmo/if_flight_legacy=>action_code-delete ) )
        IMPORTING
          et_messages = messages.

      map_messages(
        EXPORTING
          cid        = <booking>-%cid_ref
          travel_id  = <booking>-travelid
          booking_id = <booking>-bookingid
          messages   = messages
        CHANGING
          failed   = failed-booking
          reported = reported-booking ).
    ENDLOOP.
  ENDMETHOD.

  METHOD read.
  ENDMETHOD.

  METHOD rba_Travel.
  DATA: travel   TYPE /dmo/travel,
          messages TYPE /dmo/t_message.

    "Only one function call for each requested travelid
    LOOP AT keys_rba ASSIGNING FIELD-SYMBOL(<booking_by_travel>)
                               GROUP BY <booking_by_travel>-travelid .

      CALL FUNCTION '/DMO/FLIGHT_TRAVEL_READ'
        EXPORTING
          iv_travel_id = <booking_by_travel>-travelid
        IMPORTING
          es_travel    = travel
          et_messages  = messages.

      map_messages(
        EXPORTING
          travel_id  = <booking_by_travel>-travelid
          booking_id = <booking_by_travel>-bookingid
          messages   = messages
        IMPORTING
          failed_added = DATA(failed_added)
        CHANGING
          failed   = failed-booking
          reported = reported-booking ).


      IF failed_added = abap_false.
        LOOP AT keys_rba ASSIGNING FIELD-SYMBOL(<travel>) USING KEY entity WHERE TravelID = <booking_by_travel>-TravelID.
          INSERT VALUE #(
              source-%tky     = <travel>-%tky
              target-travelid = <travel>-TravelID
            ) INTO TABLE association_links.

          IF result_requested = abap_true.
            APPEND CORRESPONDING #( travel MAPPING TO ENTITY ) TO result.
          ENDIF.
        ENDLOOP.
      ENDIF.

    ENDLOOP.

    SORT association_links BY source ASCENDING.
    DELETE ADJACENT DUPLICATES FROM association_links COMPARING ALL FIELDS.

    SORT result BY %tky ASCENDING.
    DELETE ADJACENT DUPLICATES FROM result COMPARING ALL FIELDS.
  ENDMETHOD.

  METHOD map_messages.
    failed_added = abap_false.
    LOOP AT messages INTO DATA(message).
      IF message-msgty = 'E' OR message-msgty = 'A'.
        APPEND VALUE #( %cid        = cid
                        travelid    = travel_id
                        bookingid   = booking_id
                        %fail-cause = /dmo/cl_travel_auxiliary=>get_cause_from_message(
                                        msgid = message-msgid
                                        msgno = message-msgno
                                      ) )
            TO failed.
        failed_added = abap_true.
      ENDIF.

      APPEND VALUE #( %msg = new_message(
                                id       = message-msgid
                                number   = message-msgno
                                severity = if_abap_behv_message=>severity-error
                                v1       = message-msgv1
                                v2       = message-msgv2
                                v3       = message-msgv3
                                v4       = message-msgv4 )
                      %cid          = cid
                      TravelID      = travel_id
                      BookingID     = booking_id )
        TO reported.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
