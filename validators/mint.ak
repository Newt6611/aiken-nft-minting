use aiken/collection/list
use cardano/address.{Script}
use cardano/assets.{AssetName, PolicyId, Value}
use cardano/transaction.{Output, OutputReference, Transaction}
use nft_minting/types.{BurnEmpty, Init, Mint, MintAction}

validator nft_minting(utxo_ref: OutputReference) {
  mint(rdmr: MintAction, policy_id: PolicyId, tx: Transaction) {
    let Transaction { inputs, outputs, mint, .. } = tx

    when rdmr is {
      // Make sure it's oneshot
      Init -> {
        expect
          list.any(inputs, fn(input) { input.output_reference == utxo_ref })?

        // Only one UTxO must be produced at the script address.
        expect [Output { value: list_head_value, .. }] =
          list.filter(
            outputs,
            fn(output) {
              output.address.payment_credential == Script(policy_id)
            },
          )

        // Init can only mint one token
        expect [mint_value] = mint |> assets.flatten

        let (mint_policy, mint_name, mint_quantity) = mint_value

        // Make sure only mint one token and its name is empty
        expect (mint_policy == policy_id)?
        expect (mint_name == #"")?
        expect (mint_quantity == 1)?

        // Make sure the list head utxo only has minted one token
        let list_head_asset = get_single_asset_from_value(list_head_value)

        (list_head_asset == mint_value)?
      }
      Mint -> {
        // A single UTxO must be getting spent from the spending endpoint.
        expect [own_input] =
          list.filter(
            inputs,
            fn(input) {
              input.output.address.payment_credential == Script(policy_id)
            },
          )

        // The input UTxO should only have one empty AssetName token.
        expect [own_input_value] =
          own_input.output.value
            |> assets.without_lovelace
            |> assets.flatten

        // The first output UTxO should contains the empty AssetName token.
        expect [own_output, ..] =
          list.filter(
            outputs,
            fn(output) {
              output.address.payment_credential == Script(policy_id)
            },
          )

        expect [own_output_value] =
          own_output.value |> assets.without_lovelace |> assets.flatten

        let (own_output_policy, own_output_name, own_output_quantity) =
          own_output_value

        expect (own_input_value == own_output_value)?

        expect (own_output_policy == policy_id)?
        expect (own_output_name == #"")?
        expect (own_output_quantity == 1)?

        // New minted asset should not be empty asset name
        let minted_assets = mint |> assets.flatten
        expect [] =
          list.filter(
            minted_assets,
            fn((_, asset_name, _)) { asset_name == #"" },
          )

        True
      }
      BurnEmpty -> {
        expect [_] =
          list.filter(
            inputs,
            fn(input) {
              input.output.address.payment_credential == Script(policy_id)
            },
          )

        // Can only burn one empty asset name token
        expect [burn_value] = mint |> assets.flatten

        let (burn_policy, burn_name, burn_quantity) = burn_value

        and {
          (burn_policy == policy_id)?,
          (burn_name == #"")?,
          (burn_quantity == -1)?,
        }
      }
    }
  }

  spend(_d: Option<Data>, _r: Data, _o: Data, _tx: Transaction) {
    // Do your custom minting logic
    True
  }

  else(_) {
    fail
  }
}

fn get_single_asset_from_value(v: Value) -> (PolicyId, AssetName, Int) {
  // A single asset was expected.
  expect [triplet] =
    v
      |> assets.without_lovelace
      |> assets.flatten
  triplet
}
